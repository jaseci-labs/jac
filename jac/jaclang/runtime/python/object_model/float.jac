import from c {
    glob PyType_Type: PyTypeObject; def _Py_dg_dtoa(
        d: f64,
        mode: i32,
        ndigits: i32,
        decpt: &mut i32,
        sign: &mut i32,
        rve: &mut ptr[u8]
    ) -> ptr[u8];  def _Py_dg_strtod(s: ptr[u8], end: ptr) -> f64;  def _Py_dg_freedtoa(
        s: ptr[u8]
    );  def _Py_parse_inf_or_nan(p: ptr[u8], endptr: &mut ptr[u8]) -> f64;  def _PyFloat_FormatAdvancedWriter(
        writer: ptr[_PyUnicodeWriter],
        ob: ptr[PyObject],
        format_spec: ptr[PyObject],
        start: i64,
        end: i64
    ) -> i32;  def _PyUnicode_FromASCII(s: ptr[u8], size: i64) -> ptr[PyObject];  def _PyStructSequence_InitBuiltinWithFlags(
        interp: ptr, type: ptr[PyObject], desc: ptr[PyStructSequence_Desc], flags: u64
    ) -> i32;  def _PyStructSequence_FiniBuiltin(interp: ptr, type: ptr[PyObject]);  def _PyArg_BadArgument(
        fname: str, displayname: str, expected: str, arg: ptr[PyObject]
    );  def _PyDebugAllocatorStats(
        out: ptr, block_name: str, num_blocks: i32, sizeof_block: u64
    );  def strtol(s: ptr[u8], end: ptr, base: i32) -> i64;  def strlen(
        s: ptr[u8]
    ) -> u64;  def strcmp(left: ptr[u8], right: str) -> i32;  glob:priv parse_end:
             ptr[u8] = ptr[u8](),
         float_as_number: PyNumberMethods = PyNumberMethods(
             nb_add=float_add,
             nb_subtract=float_sub,
             nb_multiply=float_mul,
             nb_remainder=float_rem,
             nb_divmod=float_divmod,
             nb_power=float_pow,
             nb_negative=float_neg,
             nb_positive=float_float,
             nb_absolute=float_abs,
             nb_bool=float_bool,
             nb_int=float_trunc_slot,
             nb_float=float_float,
             nb_floor_divide=float_floor_div,
             nb_true_divide=float_div
         ),
         float_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("from_number"),
                 ml_meth=ptr(float_from_number),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "from_number($type, number, /)\n--\n\n"
                     "Convert real number to a floating-point number."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("conjugate"),
                 ml_meth=ptr(float_conjugate),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "conjugate($self, /)\n--\n\n"
                     "Return self, the complex conjugate of any float."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__trunc__"),
                 ml_meth=ptr(float___trunc__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__trunc__($self, /)\n--\n\n"
                     "Return the Integral closest to x between 0 and x."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__floor__"),
                 ml_meth=ptr(float___floor__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__floor__($self, /)\n--\n\nReturn the floor as an Integral."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__ceil__"),
                 ml_meth=ptr(float___ceil__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__ceil__($self, /)\n--\n\nReturn the ceiling as an Integral."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__round__"),
                 ml_meth=ptr(float___round__),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "__round__($self, ndigits=None, /)\n--\n\n"
                     "Return the Integral closest to x, rounding half toward even.\n\n"
                     "When an argument is passed, work like built-in round(x, ndigits)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("as_integer_ratio"),
                 ml_meth=ptr(float_as_integer_ratio),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "as_integer_ratio($self, /)\n--\n\n"
                     "Return a pair of integers, whose ratio is exactly equal to the original float.\n\n"
                     "The ratio is in lowest terms and has a positive denominator.  Raise\n"
                     "OverflowError on infinities and a ValueError on NaNs.\n\n"
                     ">>> (10.0).as_integer_ratio()\n"
                     "(10, 1)\n"
                     ">>> (0.0).as_integer_ratio()\n"
                     "(0, 1)\n"
                     ">>> (-.25).as_integer_ratio()\n"
                     "(-1, 4)"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("fromhex"),
                 ml_meth=ptr(float_fromhex),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "fromhex($type, string, /)\n--\n\n"
                     "Create a floating-point number from a hexadecimal string.\n\n"
                     ">>> float.fromhex('0x1.ffffp10')\n"
                     "2047.984375\n"
                     ">>> float.fromhex('-0x1p-1074')\n"
                     "-5e-324"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("hex"),
                 ml_meth=ptr(float_hex),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "hex($self, /)\n--\n\n"
                     "Return a hexadecimal representation of a floating-point number.\n\n"
                     ">>> (-0.1).hex()\n"
                     "'-0x1.999999999999ap-4'\n"
                     ">>> 3.14159.hex()\n"
                     "'0x1.921f9f01b866ep+1'"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_integer"),
                 ml_meth=ptr(float_is_integer),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_integer($self, /)\n--\n\nReturn True if the float is an integer."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__getnewargs__"),
                 ml_meth=ptr(float___getnewargs__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__getnewargs__($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__getformat__"),
                 ml_meth=ptr(float___getformat__),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "__getformat__($type, typestr, /)\n--\n\n"
                     "You probably don't want to use this function.\n\n"
                     "  typestr\n"
                     "    Must be 'double' or 'float'.\n\n"
                     "It exists mainly to be used in Python's test suite.\n\n"
                     "This function returns whichever of 'unknown', 'IEEE, big-endian' or\n"
                     "'IEEE, little-endian' best describes the format of floating-point\n"
                     "numbers used by the C type named by typestr."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__format__"),
                 ml_meth=ptr(float___format__),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "__format__($self, format_spec, /)\n--\n\n"
                     "Formats the float according to format_spec."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         float_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("real"),
                 get=float_getreal,
                 doc=ptr[u8]("the real part of a complex number")
             ),
             PyGetSetDef(
                 name=ptr[u8]("imag"),
                 get=float_getimag,
                 doc=ptr[u8]("the imaginary part of a complex number")
             ),
             PyGetSetDef()
         ],
         floatinfo_fields: list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("max"),
                 doc=ptr[u8]("DBL_MAX -- maximum representable finite float")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("max_exp"),
                 doc=ptr[u8](
                     "DBL_MAX_EXP -- maximum int e such that radix**(e-1) is representable"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("max_10_exp"),
                 doc=ptr[u8](
                     "DBL_MAX_10_EXP -- maximum int e such that 10**e is representable"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("min"),
                 doc=ptr[u8]("DBL_MIN -- Minimum positive normalized float")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("min_exp"),
                 doc=ptr[u8](
                     "DBL_MIN_EXP -- minimum int e such that radix**(e-1) is a normalized float"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("min_10_exp"),
                 doc=ptr[u8](
                     "DBL_MIN_10_EXP -- minimum int e such that 10**e is a normalized float"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("dig"),
                 doc=ptr[u8](
                     "DBL_DIG -- maximum number of decimal digits that can be faithfully represented in a float"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("mant_dig"),
                 doc=ptr[u8]("DBL_MANT_DIG -- mantissa digits")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("epsilon"),
                 doc=ptr[u8](
                     "DBL_EPSILON -- Difference between 1 and the next representable float"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("radix"), doc=ptr[u8]("FLT_RADIX -- radix of exponent")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("rounds"),
                 doc=ptr[u8](
                     "FLT_ROUNDS -- rounding mode used for arithmetic operations"
                 )
             ),
             PyStructSequence_Field()
         ],
         floatinfo_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("sys.float_info"),
             doc=ptr[u8](
                 "sys.float_info\n\n"
                 "A named tuple holding information about the float type. It contains low level\n"
                 "information about the precision and internal representation. Please study\n"
                 "your system's :file:`float.h` for more information."
             ),
             fields=addressof(floatinfo_fields),
             n_in_sequence=11
         ),
         FloatInfoType: PyTypeObject = PyTypeObject(); glob PyFloat_Type:
             PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("float"),
             tp_basicsize=PyFloatObject_SIZE,
             tp_dealloc=float_dealloc,
             tp_repr=float_repr,
             tp_as_number=addressof(float_as_number),
             tp_hash=float_hash,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | _Py_TPFLAGS_MATCH_SELF,
             tp_doc=ptr[u8](
                 "float(x=0, /)\n--\n\n"
                 "Convert a string or number to a floating-point number, if possible."
             ),
             tp_richcompare=float_richcompare,
             tp_methods=addressof(float_methods),
             tp_getset=addressof(float_getset),
             tp_new=float_new,
             tp_vectorcall=float_vectorcall,
             tp_version_tag=_Py_TYPE_VERSION_FLOAT
         );
}

glob:priv DBL_MAX: f64 = 1.7976931348623157e308,
     DBL_MIN: f64 = 2.2250738585072014e-308,
     DBL_EPSILON: f64 = 2.220446049250313e-16,
     DBL_MAX_EXP: i64 = 1024,
     DBL_MIN_EXP: i64 = -1021,
     DBL_MANT_DIG: i64 = 53,
     LONG_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     LONG_MIN: i64 = -0x7FFFFFFFFFFFFFFF - 1,
     DTOA_FIXED: i32 = 3,
     CONVERTED: i64 = 0,
     NOT_A_NUMBER: i64 = 1,
     CONVERT_FAILED: i64 = -1,
     FORMAT_UNKNOWN: i64 = 0,
     FORMAT_IEEE_BIG_ENDIAN: i64 = 1,
     FORMAT_IEEE_LITTLE_ENDIAN: i64 = 2,
     PYREFTRACER_DESTROY: i32 = 1;

glob:priv double_format: i64 = 0,
     float_format: i64 = 0;

def float_of(op: ptr[PyObject]) -> ptr[PyFloatObject];

def float_value(op: ptr[PyObject]) -> f64;

def float_type -> ptr[PyTypeObject];

def float_check_exact(op: ptr[PyObject]) -> bool;

def float_check(op: ptr[PyObject]) -> bool;

def long_check(op: ptr[PyObject]) -> bool;

def huge_val -> f64;

def is_nan(x: f64) -> bool;

def is_inf(x: f64) -> bool;

def is_finite(x: f64) -> bool;

def is_space(c: u8) -> bool;

import from c {
    def PyFloat_GetMax -> f64 {
        return DBL_MAX;
    }  def PyFloat_GetMin -> f64 {
        return DBL_MIN;
    }  def PyFloat_GetInfo -> ptr[PyObject] {
        floatinfo = PyStructSequence_New(ptr[PyObject](addressof(FloatInfoType)));
        if not floatinfo {
            return NULL;
        }
        flags = [
            PyFloat_FromDouble(DBL_MAX),
            PyLong_FromLong(DBL_MAX_EXP),
            PyLong_FromLong(308),
            PyFloat_FromDouble(DBL_MIN),
            PyLong_FromLong(DBL_MIN_EXP),
            PyLong_FromLong(-307),
            PyLong_FromLong(15),
            PyLong_FromLong(DBL_MANT_DIG),
            PyFloat_FromDouble(DBL_EPSILON),
            PyLong_FromLong(2),
            PyLong_FromLong(1)
        ];

        failed = False;
        for pos in range(len(flags)) {
            if flags[pos] {
                tuple_set_item(floatinfo, pos, flags[pos]);
            } else {
                failed = True;
            }
        }
        if failed {
            object_decref(floatinfo);
            return NULL;
        }
        return floatinfo;
    }  def PyFloat_FromDouble(fval: f64) -> ptr[PyObject] {
        op = freelist_pop(_Py_freelists_FLOATS);
        if not op {
            op = ptr[PyObject](PyObject_Malloc(u64(PyFloatObject_SIZE)));
            if not op {
                return PyErr_NoMemory();
            }
            PyObject_Init(op, ptr[PyObject](float_type()));
        }
        float_of(op).view(1)[0].ob_fval = fval;
        return op;
    }  def _PyFloat_FromDouble_ConsumeInputs(left: u64, right: u64, value: f64) -> u64 {
        close_float_ref(left);
        close_float_ref(right);
        result = PyFloat_FromDouble(value);
        if not result {
            return u64(1);
        }
        return stackref_steal(result);
    }  def PyFloat_FromString(v: ptr[PyObject]) -> ptr[PyObject] {
        s = ptr[u8]();
        length: i64 = 0;
        s_buffer = NULL;
        view = ptr[Py_buffer]();
        if type_has_feature(object_type(v), Py_TPFLAGS_UNICODE_SUBCLASS) {
            s_buffer = _PyUnicode_TransformDecimalAndSpaceToASCII(v);
            if not s_buffer {
                return NULL;
            }

            s = PyUnicode_AsUTF8AndSize(s_buffer, &mut length);
        } elif type_has_feature(object_type(v), Py_TPFLAGS_BYTES_SUBCLASS) {
            s = ptr[u8](PyBytes_AsString(v));
            length = object_size(v);
        } elif object_type_check(v, type_of_object(addressof(PyByteArray_Type))) {
            s = ptr[u8](PyByteArray_AsString(v));
            length = object_size(v);
        } else {
            view = ptr[Py_buffer](PyMem_Calloc(1, 80));
            if not view {
                return PyErr_NoMemory();
            }
            if PyObject_GetBuffer(v, view, PyBUF_SIMPLE) != 0 {
                PyMem_Free(ptr(view));
                PyErr_Format(
                    PyExc_TypeError,
                    "float() argument must be a string or a real number, not '%.200s'",
                    object_type(v).view(1)[0].tp_name
                );
                return NULL;
            }
            s_buffer = PyBytes_FromStringAndSize(
                ptr[u8](view.view(1)[0].buf), view.view(1)[0].length
            );
            if not s_buffer {
                PyBuffer_Release(view);
                PyMem_Free(ptr(view));
                return NULL;
            }
            s = ptr[u8](PyBytes_AsString(s_buffer));
            length = object_size(s_buffer);
        }
        result = _Py_string_to_number_with_underscores(
            ptr(s), length, "float", v, ptr(v), ptr(float_from_string_inner)
        );
        if view {
            PyBuffer_Release(view);
            PyMem_Free(ptr(view));
        }
        object_xdecref(s_buffer);
        return result;
    }  def _PyFloat_ExactDealloc(ob: ptr[PyObject]) {
        if not freelist_push(_Py_freelists_FLOATS, ob, Py_floats_MAXFREELIST) {
            PyObject_Free(ptr(ob));
        }
    }  def PyFloat_AsDouble(op: ptr[PyObject]) -> f64 {
        if not op {
            PyErr_BadArgument();
            return -1.0;
        }
        if float_check(op) {
            return float_value(op);
        }
        nb = object_type(op).view(1)[0].tp_as_number;
        if not nb or int(nb.view(1)[0].nb_float) == 0 {
            if nb and int(nb.view(1)[0].nb_index) != 0 {
                index = _PyNumber_Index(op);
                if not index {
                    return -1.0;
                }
                value = PyLong_AsDouble(index);
                object_decref(index);
                return value;
            }
            PyErr_Format(
                PyExc_TypeError,
                "must be real number, not %.50s",
                object_type(op).view(1)[0].tp_name
            );
            return -1.0;
        }
        res = nb.view(1)[0].nb_float(op);
        if not res {
            return -1.0;
        }
        if not float_check_exact(res) {
            if not float_check(res) {
                PyErr_Format(
                    PyExc_TypeError,
                    "%.50s.__float__ returned non-float (type %.50s)",
                    object_type(op).view(1)[0].tp_name,
                    object_type(res).view(1)[0].tp_name
                );
                object_decref(res);
                return -1.0;
            }
            if PyErr_WarnFormat(
                PyExc_DeprecationWarning,
                1,
                "%.50s.__float__ returned non-float (type %.50s).  The ability to return an instance of a strict subclass of float is deprecated, and may be removed in a future version of Python.",
                object_type(op).view(1)[0].tp_name,
                object_type(res).view(1)[0].tp_name
            )
                != 0 {
                object_decref(res);
                return -1.0;
            }
        }
        value = float_value(res);
        object_decref(res);
        return value;
    }  def _Py_convert_int_to_double(v: ptr[ptr[PyObject]], dbl: ptr[f64]) -> i32 {
        ob = v.view(1)[0];
        if long_check(ob) {
            value = PyLong_AsDouble(ob);
            dbl.view(1)[0] = value;
            if value == -1.0 and PyErr_Occurred() {
                v.view(1)[0] = NULL;
                return i32(-1);
            }
            return i32(0);
        }
        v.view(1)[0] = object_new_ref(Py_NotImplemented);
        return i32(-1);
    }
}

def type_of_object(type: ptr[PyObject]) -> ptr[PyTypeObject];

def stackref_steal(op: ptr[PyObject]) -> u64;

def close_float_ref(ref: u64);

def float_from_string_inner(s_in: ptr[u8], length: i64, ob: ptr) -> ptr[PyObject];

def float_dealloc(op: ptr[PyObject]);

def convert_to_double(ob: ptr[PyObject]) -> tuple[f64, i64];

def unconverted(status: i64) -> ptr[PyObject];

def float_repr(op: ptr[PyObject]) -> ptr[PyObject];

def compare_doubles(i: f64, j: f64, op: i32) -> ptr[PyObject];

def float_richcompare(v: ptr[PyObject], w: ptr[PyObject], op_in: i32) -> ptr[PyObject];

def float_hash(op: ptr[PyObject]) -> i64;

def float_add(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def float_sub(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def float_mul(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def float_div(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def float_rem(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def float_div_mod(vx: f64, wx: f64) -> tuple[f64, f64];

def float_divmod(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def float_floor_div(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def double_is_odd_integer(x: f64) -> bool;

def float_pow(v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]) -> ptr[PyObject];

def float_neg(op: ptr[PyObject]) -> ptr[PyObject];

def float_abs(op: ptr[PyObject]) -> ptr[PyObject];

def float_bool(op: ptr[PyObject]) -> i32;

def float_is_integer(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def float_trunc_slot(op: ptr[PyObject]) -> ptr[PyObject];

def float___trunc__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def float___floor__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def float___ceil__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def put_byte(p: ptr[u8], c: i64) -> ptr[u8];

def put_decimal(p_in: ptr[u8], value: i64) -> ptr[u8];

def double_round(x: f64, ndigits: i32) -> ptr[PyObject];

def float___round__(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def float_float(op: ptr[PyObject]) -> ptr[PyObject];

def float_conjugate(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def hex_from_char(c: u8) -> i64;

def char_from_hex(x: i64) -> i64;

glob:priv TOHEX_NBITS: i64 = 53;

def float_hex(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def hex_digit(coeff_end: ptr[u8], fdigits: i64, j: i64) -> i64;

glob:priv FROMHEX_PARSE_ERROR: i64 = 1,
     FROMHEX_OVERFLOW: i64 = 2,
     FROMHEX_TOO_LONG: i64 = 3;

def parse_hex_float(s_in: ptr[u8]) -> tuple[f64, ptr[u8], i64];

def float_fromhex(type: ptr[PyObject], string: ptr[PyObject]) -> ptr[PyObject];

def float_as_integer_ratio(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def float_new_impl(type: ptr[PyTypeObject], x: ptr[PyObject]) -> ptr[PyObject];

def float_subtype_new(type: ptr[PyTypeObject], x: ptr[PyObject]) -> ptr[PyObject];

def float_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def float_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def float_from_number(type: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject];

def float___getnewargs__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def float___getformat__(type: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def float_getreal(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def float_getimag(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def float___format__(op: ptr[PyObject], format_spec: ptr[PyObject]) -> ptr[PyObject];

def native_little_endian -> bool;

def reverse_bytes(p: ptr[u8], n: i64);

def must_swap(format: i64, le: i32) -> bool;

import from c {
    def _PyFloat_InitState(interp: ptr) {
        if interp != ptr(PyInterpreterState_Main()) {
            return;
        }

        detected = FORMAT_IEEE_LITTLE_ENDIAN
            if native_little_endian()
            else FORMAT_IEEE_BIG_ENDIAN;
        double_format = detected;
        float_format = detected;
    }  def _PyFloat_InitTypes(interp: ptr) -> PyStatus {
        if _PyStructSequence_InitBuiltinWithFlags(
            interp,
            ptr[PyObject](addressof(FloatInfoType)),
            addressof(floatinfo_desc),
            u64(0)
        )
            < 0 {
            return PyStatus(
                _type=_PyStatus_TYPE_ERROR,
                func=ptr[u8]("_PyFloat_InitTypes"),
                err_msg=ptr[u8]("can't init float info type"),
                exitcode=0
            );
        }
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }  def _PyFloat_FiniType(interp: ptr) {
        _PyStructSequence_FiniBuiltin(interp, ptr[PyObject](addressof(FloatInfoType)));
    }  def _PyFloat_DebugMallocStats(out: ptr) {
        _PyDebugAllocatorStats(
            out,
            "free PyFloatObject",
            i32(freelist(_Py_freelists_FLOATS).view(1)[0].size),
            u64(PyFloatObject_SIZE)
        );
    }  def PyFloat_Pack2(x_in: f64, data: ptr[u8], le: i32) -> i32 {
        x = x_in;
        sign = 0;
        e = 0;
        bits = 0;
        if x == 0.0 {
            sign = 1 if copysign(1.0, x) == -1.0 else 0;
        } elif is_inf(x) {
            sign = 1 if x < 0.0 else 0;
            e = 0x1F;
        } elif is_nan(x) {
            sign = 1 if copysign(1.0, x) == -1.0 else 0;
            e = 0x1F;
            v = jacpy_float_bits(x) & u64(0xffc0000000000);
            bits = i64(v >> u64(42));
            if bits == 0 {
                bits = bits | (1 << 9);
            }
        } else {
            sign = 1 if x < 0.0 else 0;
            if sign != 0 {
                x = -x;
            }
            fe = i32(0);
            f = frexp(x, &mut fe);
            e = i64(fe);
            if f < 0.5 or f >= 1.0 {
                PyErr_SetString(PyExc_SystemError, "frexp() result out of range");
                return i32(-1);
            }
            f *= 2.0;
            e -= 1;
            if e >= 16 {
                PyErr_SetString(
                    PyExc_OverflowError, "float too large to pack with e format"
                );
                return i32(-1);
            } elif e < -25 {
                f = 0.0;
                e = 0;
            } elif e < -14 {
                f = ldexp(f, i32(14 + e));
                e = 0;
            } else {
                e += 15;
                f -= 1.0;
            }
            f *= 1024.0;
            bits = i64(f);
            rest = f - f64(bits);
            if rest > 0.5 or (rest == 0.5 and bits % 2 == 1) {
                bits += 1;
                if bits == 1024 {
                    bits = 0;
                    e += 1;
                    if e == 31 {
                        PyErr_SetString(
                            PyExc_OverflowError, "float too large to pack with e format"
                        );
                        return i32(-1);
                    }
                }
            }
        }
        bits = bits | (e << 10) | (sign << 15);
        p = data;
        incr = 1;
        if le != i32(0) {
            p = p + 1;
            incr = -1;
        }
        p.view(1)[0] = u8((bits >> 8) & 0xFF);
        (p + incr).view(1)[0] = u8(bits & 0xFF);
        return i32(0);
    }  def PyFloat_Pack4(x: f64, data: ptr[u8], le: i32) -> i32 {
        y = f32(x);
        if is_inf(f64(y)) and not is_inf(x) {
            PyErr_SetString(
                PyExc_OverflowError, "float too large to pack with f format"
            );
            return i32(-1);
        }
        ptr[f32](data).view(1)[0] = y;
        if is_nan(x) {
            if (jacpy_float_bits(x) & (u64(1) << u64(51))) == u64(0) {
                word = ptr[u32](data).view(1)[0];
                if (word & u32(0x3fffff)) != u32(0) {
                    ptr[u32](data).view(1)[0] = word & ~u32(1 << 22);
                }
            }
        }
        if must_swap(float_format, le) {
            reverse_bytes(data, 4);
        }
        return i32(0);
    }  def PyFloat_Pack8(x: f64, data: ptr[u8], le: i32) -> i32 {
        ptr[f64](data).view(1)[0] = x;
        if must_swap(double_format, le) {
            reverse_bytes(data, 8);
        }
        return i32(0);
    }  def PyFloat_Unpack2(data: ptr[u8], le: i32) -> f64 {
        p = data;
        incr = 1;
        if le != i32(0) {
            p = p + 1;
            incr = -1;
        }
        first = i64(p.view(1)[0]);
        sign = (first >> 7) & 1;
        e = (first & 0x7C) >> 2;
        f = (first & 0x03) << 8;
        f = f | i64((p + incr).view(1)[0]);
        if e == 0x1F {
            if f == 0 {
                return -huge_val() if sign != 0 else huge_val();
            }

            v = u64(0xfff0000000000000) if sign != 0 else u64(0x7ff0000000000000);
            v += u64(f) << u64(42);
            return jacpy_float_from_bits(v);
        }
        x = f64(f) / 1024.0;
        if e == 0 {
            e = -14;
        } else {
            x += 1.0;
            e -= 15;
        }
        x = ldexp(x, i32(e));
        return -x if sign != 0 else x;
    }  def PyFloat_Unpack4(data: ptr[u8], le: i32) -> f64 {
        word = u32(0);
        if must_swap(float_format, le) {
            word = (u32(data.view(1)[0]) << u32(24))
                | (u32((data + 1).view(1)[0]) << u32(16))
                | (u32((data + 2).view(1)[0]) << u32(8))
                | u32((data + 3).view(1)[0]);
        } else {
            word = ptr[u32](data).view(1)[0];
        }
        x = f64(f32_from_bits(word));
        if is_nan(x) and (word & u32(1 << 22)) == u32(0) {
            return jacpy_float_from_bits(jacpy_float_bits(x) & ~(u64(1) << u64(51)));
        }
        return x;
    }  def PyFloat_Unpack8(data: ptr[u8], le: i32) -> f64 {
        if must_swap(double_format, le) {
            bits = u64(0);
            for k in range(8) {
                bits = (bits << u64(8)) | u64((data + k).view(1)[0]);
            }
            return jacpy_float_from_bits(bits);
        }
        return ptr[f64](data).view(1)[0];
    }
}

def f32_from_bits(word: u32) -> f32;

import from c { glob:priv f32_slot: u64 = u64(0); }

impl float_of(op: ptr[PyObject]) -> ptr[PyFloatObject] {
    return ptr[PyFloatObject](op);
}

impl float_value(op: ptr[PyObject]) -> f64 {
    return float_of(op).view(1)[0].ob_fval;
}

impl float_type -> ptr[PyTypeObject] {
    return addressof(PyFloat_Type);
}

impl float_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, float_type());
}

impl float_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, float_type());
}

impl long_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl huge_val -> f64 {
    return jacpy_float_from_bits(u64(0x7ff0000000000000));
}

impl is_nan(x: f64) -> bool {
    return x != x;
}

impl is_inf(x: f64) -> bool {
    return x == x and x - x != 0.0;
}

impl is_finite(x: f64) -> bool {
    return x - x == 0.0;
}

impl is_space(c: u8) -> bool {
    return c == u8(32) or (c >= u8(9) and c <= u8(13));
}

impl type_of_object(type: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[PyTypeObject](type);
}

impl stackref_steal(op: ptr[PyObject]) -> u64 {
    flags = u64.wrap(ptr[_object](op).view(1)[0].ob_refcnt_full) >> u64(48);
    return u64.wrap(int(op)) | (flags & u64(1));
}

impl close_float_ref(ref: u64) {
    if (ref & u64(1)) != u64(0) {
        return;
    }
    op = ptr[PyObject](i64.wrap(ref));
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full - 1;
    header.view(1)[0].ob_refcnt_full = full;
    if (full & 0xFFFFFFFF) == 0 {
        reftracer_track(op, PYREFTRACER_DESTROY);
        _PyFloat_ExactDealloc(op);
    }
}

impl float_from_string_inner(s_in: ptr[u8], length: i64, ob: ptr) -> ptr[PyObject] {
    s = s_in;
    last = s_in + length;

    while s < last and is_space(s.view(1)[0]) {
        s = s + 1;
    }
    if s == last {
        PyErr_Format(
            PyExc_ValueError, "could not convert string to float: %R", ptr[PyObject](ob)
        );
        return NULL;
    }

    while s < last - 1 and is_space((last - 1).view(1)[0]) {
        last = last - 1;
    }

    end_slot = addressof(parse_end);
    x = PyOS_string_to_double(s, ptr(end_slot), NULL);
    if end_slot.view(1)[0] != last {
        PyErr_Format(
            PyExc_ValueError, "could not convert string to float: %R", ptr[PyObject](ob)
        );
        return NULL;
    }
    if x == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    return PyFloat_FromDouble(x);
}

impl float_dealloc(op: ptr[PyObject]) {
    if float_check_exact(op) {
        _PyFloat_ExactDealloc(op);
    } else {
        object_type(op).view(1)[0].tp_free(ptr(op));
    }
}

impl convert_to_double(ob: ptr[PyObject]) -> tuple[f64, i64] {
    if float_check(ob) {
        return (float_value(ob), CONVERTED);
    }
    if long_check(ob) {
        value = PyLong_AsDouble(ob);
        if value == -1.0 and PyErr_Occurred() {
            return (value, CONVERT_FAILED);
        }
        return (value, CONVERTED);
    }
    return (0.0, NOT_A_NUMBER);
}

impl unconverted(status: i64) -> ptr[PyObject] {
    if status == NOT_A_NUMBER {
        return object_new_ref(Py_NotImplemented);
    }
    return NULL;
}

impl float_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    buf = PyOS_double_to_string(float_value(op), i8(114), 0, Py_DTSF_ADD_DOT_0, None);
    if not buf {
        return PyErr_NoMemory();
    }
    result = _PyUnicode_FromASCII(ptr[u8](buf), i64(strlen(ptr[u8](buf))));
    PyMem_Free(ptr(buf));
    return result;
}

impl compare_doubles(i: f64, j: f64, op: i32) -> ptr[PyObject] {
    r = False;
    if op == Py_EQ {
        r = i == j;
    } elif op == Py_NE {
        r = i != j;
    } elif op == Py_LE {
        r = i <= j;
    } elif op == Py_GE {
        r = i >= j;
    } elif op == Py_LT {
        r = i < j;
    } elif op == Py_GT {
        r = i > j;
    }
    return PyBool_FromLong(1 if r else 0);
}

impl float_richcompare(
    v: ptr[PyObject], w: ptr[PyObject], op_in: i32
) -> ptr[PyObject] {
    op = op_in;
    i = float_value(v);
    if float_check(w) {
        return compare_doubles(i, float_value(w), op);
    }
    if not long_check(w) {
        return object_new_ref(Py_NotImplemented);
    }
    if not is_finite(i) {
        return compare_doubles(i, 0.0, op);
    }
    vsign = 0 if i == 0.0 else (-1 if i < 0.0 else 1);
    wsign = i32(0);
    PyLong_GetSign(w, &mut wsign);
    if vsign != i64(wsign) {
        return compare_doubles(f64(vsign), f64(wsign), op);
    }

    nbits64 = _PyLong_NumBits(w);
    if nbits64 > DBL_MAX_EXP {
        return compare_doubles(f64(vsign), f64(wsign) * 2.0, op);
    }
    if nbits64 <= 48 {
        return compare_doubles(i, PyLong_AsDouble(w), op);
    }
    exponent = i32(0);
    frexp(i, &mut exponent);

    if i64(exponent) < nbits64 {
        return compare_doubles(0.0, i, op);
    }
    if i64(exponent) > nbits64 {
        return compare_doubles(i, 0.0, op);
    }

    intpart = 0.0;
    fracpart = modf(i, &mut intpart);
    if fracpart != 0.0 {
        if op == Py_EQ {
            return PyBool_FromLong(0);
        }
        if op == Py_NE {
            return PyBool_FromLong(1);
        }

        if op == Py_LT or op == Py_LE {
            op = Py_LT if vsign > 0 else Py_LE;
        } elif op == Py_GT or op == Py_GE {
            op = Py_GE if vsign > 0 else Py_GT;
        }
    }
    vv = PyLong_FromDouble(intpart);
    if not vv {
        return NULL;
    }
    r = PyObject_RichCompareBool(vv, w, op);
    object_decref(vv);
    if r < 0 {
        return NULL;
    }
    return PyBool_FromLong(i64(r));
}

impl float_hash(op: ptr[PyObject]) -> i64 {
    return _Py_HashDouble(op, float_value(op));
}

impl float_add(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    (a, sa) = convert_to_double(v);
    if sa != CONVERTED {
        return unconverted(sa);
    }
    (b, sb) = convert_to_double(w);
    if sb != CONVERTED {
        return unconverted(sb);
    }
    return PyFloat_FromDouble(a + b);
}

impl float_sub(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    (a, sa) = convert_to_double(v);
    if sa != CONVERTED {
        return unconverted(sa);
    }
    (b, sb) = convert_to_double(w);
    if sb != CONVERTED {
        return unconverted(sb);
    }
    return PyFloat_FromDouble(a - b);
}

impl float_mul(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    (a, sa) = convert_to_double(v);
    if sa != CONVERTED {
        return unconverted(sa);
    }
    (b, sb) = convert_to_double(w);
    if sb != CONVERTED {
        return unconverted(sb);
    }
    return PyFloat_FromDouble(a * b);
}

impl float_div(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    (a, sa) = convert_to_double(v);
    if sa != CONVERTED {
        return unconverted(sa);
    }
    (b, sb) = convert_to_double(w);
    if sb != CONVERTED {
        return unconverted(sb);
    }
    if b == 0.0 {
        PyErr_SetString(PyExc_ZeroDivisionError, "division by zero");
        return NULL;
    }
    return PyFloat_FromDouble(a / b);
}

impl float_rem(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    (vx, sa) = convert_to_double(v);
    if sa != CONVERTED {
        return unconverted(sa);
    }
    (wx, sb) = convert_to_double(w);
    if sb != CONVERTED {
        return unconverted(sb);
    }
    if wx == 0.0 {
        PyErr_SetString(PyExc_ZeroDivisionError, "division by zero");
        return NULL;
    }
    mod = fmod(vx, wx);
    if mod != 0.0 {
        if (wx < 0.0) != (mod < 0.0) {
            mod += wx;
        }
    } else {
        mod = copysign(0.0, wx);
    }
    return PyFloat_FromDouble(mod);
}

impl float_div_mod(vx: f64, wx: f64) -> tuple[f64, f64] {
    mod = fmod(vx, wx);

    div = (vx - mod) / wx;
    if mod != 0.0 {
        if (wx < 0.0) != (mod < 0.0) {
            mod += wx;
            div -= 1.0;
        }
    } else {
        mod = copysign(0.0, wx);
    }
    floordiv = 0.0;
    if div != 0.0 {
        floordiv = floor(div);
        if div - floordiv > 0.5 {
            floordiv += 1.0;
        }
    } else {
        floordiv = copysign(0.0, vx / wx);
    }
    return (floordiv, mod);
}

impl float_divmod(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    (vx, sa) = convert_to_double(v);
    if sa != CONVERTED {
        return unconverted(sa);
    }
    (wx, sb) = convert_to_double(w);
    if sb != CONVERTED {
        return unconverted(sb);
    }
    if wx == 0.0 {
        PyErr_SetString(PyExc_ZeroDivisionError, "division by zero");
        return NULL;
    }
    (floordiv, mod) = float_div_mod(vx, wx);
    return Py_BuildValue("(dd)", floordiv, mod);
}

impl float_floor_div(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    (vx, sa) = convert_to_double(v);
    if sa != CONVERTED {
        return unconverted(sa);
    }
    (wx, sb) = convert_to_double(w);
    if sb != CONVERTED {
        return unconverted(sb);
    }
    if wx == 0.0 {
        PyErr_SetString(PyExc_ZeroDivisionError, "division by zero");
        return NULL;
    }
    (floordiv, mod) = float_div_mod(vx, wx);
    return PyFloat_FromDouble(floordiv);
}

impl double_is_odd_integer(x: f64) -> bool {
    return fmod(fabs(x), 2.0) == 1.0;
}

impl float_pow(v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]) -> ptr[PyObject] {
    if z != Py_None {
        PyErr_SetString(
            PyExc_TypeError,
            "pow() 3rd argument not allowed unless all arguments are integers"
        );
        return NULL;
    }
    (iv, sa) = convert_to_double(v);
    if sa != CONVERTED {
        return unconverted(sa);
    }
    (iw, sb) = convert_to_double(w);
    if sb != CONVERTED {
        return unconverted(sb);
    }

    if iw == 0.0 {
        return PyFloat_FromDouble(1.0);
    }
    if is_nan(iv) {
        return PyFloat_FromDouble(iv);
    }
    if is_nan(iw) {
        return PyFloat_FromDouble(1.0 if iv == 1.0 else iw);
    }
    if is_inf(iw) {
        av = fabs(iv);
        if av == 1.0 {
            return PyFloat_FromDouble(1.0);
        }
        if (iw > 0.0) == (av > 1.0) {
            return PyFloat_FromDouble(fabs(iw));
        }
        return PyFloat_FromDouble(0.0);
    }
    if is_inf(iv) {
        iw_is_odd = double_is_odd_integer(iw);
        if iw > 0.0 {
            return PyFloat_FromDouble(iv if iw_is_odd else fabs(iv));
        }
        return PyFloat_FromDouble(copysign(0.0, iv) if iw_is_odd else 0.0);
    }
    if iv == 0.0 {
        iw_is_odd = double_is_odd_integer(iw);
        if iw < 0.0 {
            PyErr_SetString(PyExc_ZeroDivisionError, "zero to a negative power");
            return NULL;
        }

        return PyFloat_FromDouble(iv if iw_is_odd else 0.0);
    }
    negate_result = False;
    if iv < 0.0 {
        if iw != floor(iw) {
            complex_number = ptr[PyTypeObject](addressof(PyComplex_Type)).view(1)[
                0
            ].tp_as_number;
            return complex_number.view(1)[0].nb_power(v, w, z);
        }

        iv = -iv;
        negate_result = double_is_odd_integer(iw);
    }
    if iv == 1.0 {
        return PyFloat_FromDouble(-1.0 if negate_result else 1.0);
    }

    jacpy_set_errno(0);
    ix = pow(iv, iw);
    errno = jacpy_errno();

    if errno == 0 {
        if is_inf(ix) {
            errno = ERANGE;
        }
    } elif errno == ERANGE and ix == 0.0 {
        errno = 0;
    }
    if negate_result {
        ix = -ix;
    }
    if errno != 0 {
        jacpy_set_errno(errno);
        PyErr_SetFromErrno(
            PyExc_OverflowError if errno == ERANGE else PyExc_ValueError
        );
        return NULL;
    }
    return PyFloat_FromDouble(ix);
}

impl float_neg(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyFloat_FromDouble(-float_value(op));
}

impl float_abs(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyFloat_FromDouble(fabs(float_value(op)));
}

impl float_bool(op: ptr[PyObject]) -> i32 {
    return i32(1) if float_value(op) != 0.0 else i32(0);
}

impl float_is_integer(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    x = PyFloat_AsDouble(op);
    if x == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    if not is_finite(x) {
        return PyBool_FromLong(0);
    }
    return PyBool_FromLong(1 if floor(x) == x else 0);
}

impl float_trunc_slot(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromDouble(float_value(op));
}

impl float___trunc__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromDouble(float_value(op));
}

impl float___floor__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromDouble(floor(float_value(op)));
}

impl float___ceil__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromDouble(ceil(float_value(op)));
}

impl put_byte(p: ptr[u8], c: i64) -> ptr[u8] {
    p.view(1)[0] = u8(c);
    return p + 1;
}

impl put_decimal(p_in: ptr[u8], value: i64) -> ptr[u8] {
    p = p_in;
    if value < 0 {
        p = put_byte(p, 45);
    }
    magnitude = -value if value < 0 else value;
    start = p;
    while True {
        p = put_byte(p, 48 + magnitude % 10);
        magnitude = magnitude // 10;
        if magnitude == 0 {
            break;
        }
    }
    reverse_bytes(start, int(p) - int(start));
    return p;
}

impl double_round(x: f64, ndigits: i32) -> ptr[PyObject] {
    decpt = i32(0);
    sign = i32(0);
    buf_end = ptr[u8]();

    buf = _Py_dg_dtoa(x, DTOA_FIXED, ndigits, &mut decpt, &mut sign, &mut buf_end);
    if not buf {
        PyErr_NoMemory();
        return NULL;
    }

    buflen = int(buf_end) - int(buf);
    mybuf = ptr[u8](PyMem_Malloc(u64(buflen + 32)));
    if not mybuf {
        _Py_dg_freedtoa(buf);
        PyErr_NoMemory();
        return NULL;
    }
    out = mybuf;
    if sign != i32(0) {
        out = put_byte(out, 45);
    }
    out = put_byte(out, 48);
    jacpy_memory_copy(ptr(out), ptr(buf), buflen);
    out = put_byte(out + buflen, 101);
    out = put_decimal(out, i64(decpt) - buflen);
    out.view(1)[0] = u8(0);
    _Py_dg_freedtoa(buf);
    jacpy_set_errno(0);
    rounded = _Py_dg_strtod(mybuf, ptr());
    errno = jacpy_errno();
    PyMem_Free(ptr(mybuf));
    if errno == ERANGE and fabs(rounded) >= 1.0 {
        PyErr_SetString(PyExc_OverflowError, "rounded value too large to represent");
        return NULL;
    }
    return PyFloat_FromDouble(rounded);
}

impl float___round__(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 and _PyArg_CheckPositional("__round__", nargs, 0, 1) == 0 {
        return NULL;
    }
    o_ndigits = args.view(1)[0] if nargs >= 1 else Py_None;
    x = PyFloat_AsDouble(op);
    if o_ndigits == Py_None {
        rounded = round(x);
        if fabs(x - rounded) == 0.5 {
            rounded = 2.0 * round(x / 2.0);
        }
        return PyLong_FromDouble(rounded);
    }

    ndigits = PyNumber_AsSsize_t(o_ndigits, NULL);
    if ndigits == -1 and PyErr_Occurred() {
        return NULL;
    }

    if not is_finite(x) {
        return PyFloat_FromDouble(x);
    }

    ndigits_max = i64(f64(DBL_MANT_DIG - DBL_MIN_EXP) * 0.30103);
    ndigits_min = -i64(f64(DBL_MAX_EXP + 1) * 0.30103);
    if ndigits > ndigits_max {
        return PyFloat_FromDouble(x);
    }
    if ndigits < ndigits_min {
        return PyFloat_FromDouble(0.0 * x);
    }
    return double_round(x, i32(ndigits));
}

impl float_float(op: ptr[PyObject]) -> ptr[PyObject] {
    if float_check_exact(op) {
        return object_new_ref(op);
    }
    return PyFloat_FromDouble(float_value(op));
}

impl float_conjugate(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return float_float(op);
}

impl hex_from_char(c: u8) -> i64 {
    code = int(c);
    if code >= 48 and code <= 57 {
        return code - 48;
    }
    if code >= 97 and code <= 102 {
        return code - 87;
    }
    if code >= 65 and code <= 70 {
        return code - 55;
    }
    return -1;
}

impl char_from_hex(x: i64) -> i64 {
    return 48 + x if x < 10 else 87 + x;
}

impl float_hex(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    (x, status) = convert_to_double(op);
    if status != CONVERTED {
        return unconverted(status);
    }
    if is_nan(x) or is_inf(x) {
        return float_repr(op);
    }
    if x == 0.0 {
        if copysign(1.0, x) == -1.0 {
            return PyUnicode_FromString(ptr[u8]("-0x0.0p+0"));
        }
        return PyUnicode_FromString(ptr[u8]("0x0.0p+0"));
    }
    e = i32(0);
    m = frexp(fabs(x), &mut e);
    shift = 1 - max(DBL_MIN_EXP - i64(e), 0);
    m = ldexp(m, i32(shift));
    exponent = i64(e) - shift;

    buf = ptr[u8](PyMem_Malloc(u64(64)));
    if not buf {
        return PyErr_NoMemory();
    }
    out = buf;
    if x < 0.0 {
        out = put_byte(out, 45);
    }
    out = put_byte(put_byte(out, 48), 120);
    out = put_byte(out, char_from_hex(i64(m)));
    m -= f64(i64(m));
    out = put_byte(out, 46);
    for i in range((TOHEX_NBITS - 1) // 4) {
        m *= 16.0;
        out = put_byte(out, char_from_hex(i64(m)));
        m -= f64(i64(m));
    }
    out = put_byte(out, 112);
    if exponent >= 0 {
        out = put_byte(out, 43);
    }
    out = put_decimal(out, exponent);
    result = _PyUnicode_FromASCII(buf, int(out) - int(buf));
    PyMem_Free(ptr(buf));
    return result;
}

impl hex_digit(coeff_end: ptr[u8], fdigits: i64, j: i64) -> i64 {
    if j < fdigits {
        return hex_from_char((coeff_end - j).view(1)[0]);
    }
    return hex_from_char((coeff_end - 1 - j).view(1)[0]);
}

impl parse_hex_float(s_in: ptr[u8]) -> tuple[f64, ptr[u8], i64] {
    s = s_in;
    negate = False;

    while is_space(s.view(1)[0]) {
        s = s + 1;
    }

    coeff_end = s;
    x = _Py_parse_inf_or_nan(s, &mut coeff_end);
    if coeff_end != s {
        return (x, coeff_end, 0);
    }

    if s.view(1)[0] == u8(45) {
        s = s + 1;
        negate = True;
    } elif s.view(1)[0] == u8(43) {
        s = s + 1;
    }

    s_store = s;
    if s.view(1)[0] == u8(48) {
        s = s + 1;
        if s.view(1)[0] == u8(120) or s.view(1)[0] == u8(88) {
            s = s + 1;
        } else {
            s = s_store;
        }
    }

    coeff_start = s;
    while hex_from_char(s.view(1)[0]) >= 0 {
        s = s + 1;
    }
    s_store = s;
    if s.view(1)[0] == u8(46) {
        s = s + 1;
        while hex_from_char(s.view(1)[0]) >= 0 {
            s = s + 1;
        }
        coeff_end = s - 1;
    } else {
        coeff_end = s;
    }

    ndigits = int(coeff_end) - int(coeff_start);
    fdigits = int(coeff_end) - int(s_store);
    if ndigits == 0 {
        return (0.0, s, FROMHEX_PARSE_ERROR);
    }
    if ndigits
        > min(
            DBL_MIN_EXP - DBL_MANT_DIG - LONG_MIN // 2, LONG_MAX // 2 + 1 - DBL_MAX_EXP
        )
            // 4 {
        return (0.0, s, FROMHEX_TOO_LONG);
    }

    exp: i64 = 0;
    if s.view(1)[0] == u8(112) or s.view(1)[0] == u8(80) {
        s = s + 1;
        exp_start = s;
        if s.view(1)[0] == u8(45) or s.view(1)[0] == u8(43) {
            s = s + 1;
        }
        if not (s.view(1)[0] >= u8(48) and s.view(1)[0] <= u8(57)) {
            return (0.0, s, FROMHEX_PARSE_ERROR);
        }
        s = s + 1;
        while s.view(1)[0] >= u8(48) and s.view(1)[0] <= u8(57) {
            s = s + 1;
        }
        exp = strtol(exp_start, ptr(), i32(10));
    }

    while ndigits > 0 and hex_digit(coeff_end, fdigits, ndigits - 1) == 0 {
        ndigits -= 1;
    }
    if ndigits == 0 or exp < LONG_MIN // 2 {
        return (-0.0 if negate else 0.0, s, 0);
    }
    if exp > LONG_MAX // 2 {
        return (0.0, s, FROMHEX_OVERFLOW);
    }

    exp = exp - 4 * fdigits;

    top_exp = exp + 4 * (ndigits - 1);
    digit = hex_digit(coeff_end, fdigits, ndigits - 1);
    while digit != 0 {
        top_exp += 1;
        digit = digit // 2;
    }

    if top_exp < DBL_MIN_EXP - DBL_MANT_DIG {
        return (-0.0 if negate else 0.0, s, 0);
    }
    if top_exp > DBL_MAX_EXP {
        return (0.0, s, FROMHEX_OVERFLOW);
    }

    lsb = max(top_exp, DBL_MIN_EXP) - DBL_MANT_DIG;
    x = 0.0;
    if exp >= lsb {
        i = ndigits - 1;
        while i >= 0 {
            x = 16.0 * x + f64(hex_digit(coeff_end, fdigits, i));
            i -= 1;
        }
        x = ldexp(x, i32(exp));
        return (-x if negate else x, s, 0);
    }

    half_eps = 1 << ((lsb - exp - 1) % 4);
    key_digit = (lsb - exp - 1) // 4;
    i = ndigits - 1;
    while i > key_digit {
        x = 16.0 * x + f64(hex_digit(coeff_end, fdigits, i));
        i -= 1;
    }
    digit = hex_digit(coeff_end, fdigits, key_digit);
    x = 16.0 * x + f64(digit & (16 - 2 * half_eps));

    if (digit & half_eps) != 0 {
        round_up = False;
        if (digit & (3 * half_eps - 1)) != 0
            or (
                half_eps == 8
                and key_digit + 1 < ndigits
                and (hex_digit(coeff_end, fdigits, key_digit + 1) & 1) != 0
            ) {
            round_up = True;
        } else {
            i = key_digit - 1;
            while i >= 0 {
                if hex_digit(coeff_end, fdigits, i) != 0 {
                    round_up = True;
                    break;
                }
                i -= 1;
            }
        }
        if round_up {
            x += f64(2 * half_eps);
            if top_exp == DBL_MAX_EXP
                and x == ldexp(f64(2 * half_eps), i32(DBL_MANT_DIG)) {
                return (0.0, s, FROMHEX_OVERFLOW);
            }
        }
    }
    x = ldexp(x, i32(exp + 4 * key_digit));
    return (-x if negate else x, s, 0);
}

impl float_fromhex(type: ptr[PyObject], string: ptr[PyObject]) -> ptr[PyObject] {
    length: i64 = 0;
    s = PyUnicode_AsUTF8AndSize(string, &mut length);
    if not s {
        return NULL;
    }
    s_end = s + length;
    (x, end, failure) = parse_hex_float(s);
    if failure == FROMHEX_OVERFLOW {
        PyErr_SetString(
            PyExc_OverflowError, "hexadecimal value too large to represent as a float"
        );
        return NULL;
    }
    if failure == FROMHEX_TOO_LONG {
        PyErr_SetString(PyExc_ValueError, "hexadecimal string too long to convert");
        return NULL;
    }

    while failure == 0 and is_space(end.view(1)[0]) {
        end = end + 1;
    }
    if failure != 0 or end != s_end {
        PyErr_SetString(PyExc_ValueError, "invalid hexadecimal floating-point string");
        return NULL;
    }
    result = PyFloat_FromDouble(x);
    if type != ptr[PyObject](float_type()) and result {
        converted = PyObject_CallOneArg(type, result);
        object_decref(result);
        result = converted;
    }
    return result;
}

impl float_as_integer_ratio(
    op: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    (self_double, status) = convert_to_double(op);
    if status != CONVERTED {
        return unconverted(status);
    }
    if is_inf(self_double) {
        PyErr_SetString(
            PyExc_OverflowError, "cannot convert Infinity to integer ratio"
        );
        return NULL;
    }
    if is_nan(self_double) {
        PyErr_SetString(PyExc_ValueError, "cannot convert NaN to integer ratio");
        return NULL;
    }
    exponent = i32(0);

    float_part = frexp(self_double, &mut exponent);
    i = 0;
    while i < 300 and float_part != floor(float_part) {
        float_part *= 2.0;
        exponent -= i32(1);
        i += 1;
    }
    long_methods = ptr[PyTypeObject](addressof(PyLong_Type)).view(1)[0].tp_as_number;
    result_pair = NULL;
    numerator = PyLong_FromDouble(float_part);
    denominator = NULL;
    py_exponent = NULL;
    if numerator {
        denominator = PyLong_FromLong(1);
    }
    if denominator {
        py_exponent = PyLong_FromLong(
            i64(exponent) if exponent >= i32(0) else -i64(exponent)
        );
    }
    if py_exponent {
        if exponent > i32(0) {
            shifted = long_methods.view(1)[0].nb_lshift(numerator, py_exponent);
            object_decref(numerator);
            numerator = shifted;
        } else {
            shifted = long_methods.view(1)[0].nb_lshift(denominator, py_exponent);
            object_decref(denominator);
            denominator = shifted;
        }
        if numerator and denominator {
            result_pair = PyTuple_Pack(2, numerator, denominator);
        }
    }
    object_xdecref(py_exponent);
    object_xdecref(denominator);
    object_xdecref(numerator);
    return result_pair;
}

impl float_new_impl(type: ptr[PyTypeObject], x: ptr[PyObject]) -> ptr[PyObject] {
    if type != float_type() {
        return float_subtype_new(type, x or PyLong_FromLong(0));
    }
    if not x {
        return PyFloat_FromDouble(0.0);
    }

    if object_is_type(x, type_of_object(addressof(PyUnicode_Type))) {
        return PyFloat_FromString(x);
    }
    return PyNumber_Float(x);
}

impl float_subtype_new(type: ptr[PyTypeObject], x: ptr[PyObject]) -> ptr[PyObject] {
    tmp = float_new_impl(float_type(), x);
    if not tmp {
        return NULL;
    }
    newobj = type.view(1)[0].tp_alloc(type, 0);
    if not newobj {
        object_decref(tmp);
        return NULL;
    }
    float_of(newobj).view(1)[0].ob_fval = float_value(tmp);
    object_decref(tmp);
    return newobj;
}

impl float_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    base = float_type();
    if (type == base or int(type.view(1)[0].tp_init) == int(base.view(1)[0].tp_init))
        and kwargs
        and _PyArg_NoKeywords("float", kwargs) == 0 {
        return NULL;
    }
    nargs = object_size(args);
    if nargs > 1 and _PyArg_CheckPositional("float", nargs, 0, 1) == 0 {
        return NULL;
    }
    x = tuple_get_item(args, 0) if nargs >= 1 else NULL;
    return float_new_impl(type, x);
}

impl float_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames and _PyArg_NoKwnames("float", kwnames) == 0 {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    if nargs > 1 and _PyArg_CheckPositional("float", nargs, 0, 1) == 0 {
        return NULL;
    }
    x = args.view(1)[0] if nargs >= 1 else NULL;
    return float_new_impl(type_of_object(type), x);
}

impl float_from_number(type: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject] {
    is_float = type == ptr[PyObject](float_type());
    if float_check_exact(number) and is_float {
        return object_new_ref(number);
    }
    x = PyFloat_AsDouble(number);
    if x == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    result = PyFloat_FromDouble(x);
    if not is_float and result {
        converted = PyObject_CallOneArg(type, result);
        object_decref(result);
        result = converted;
    }
    return result;
}

impl float___getnewargs__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue("(d)", float_value(op));
}

impl float___getformat__(type: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if not type_has_feature(object_type(arg), Py_TPFLAGS_UNICODE_SUBCLASS) {
        _PyArg_BadArgument("__getformat__", "argument", "str", arg);
        return NULL;
    }
    length: i64 = 0;
    typestr = PyUnicode_AsUTF8AndSize(arg, &mut length);
    if not typestr {
        return NULL;
    }
    if i64(strlen(typestr)) != length {
        PyErr_SetString(PyExc_ValueError, "embedded null character");
        return NULL;
    }
    r = FORMAT_UNKNOWN;
    if strcmp(typestr, "double") == 0 {
        r = double_format;
    } elif strcmp(typestr, "float") == 0 {
        r = float_format;
    } else {
        PyErr_SetString(
            PyExc_ValueError, "__getformat__() argument 1 must be 'double' or 'float'"
        );
        return NULL;
    }
    if r == FORMAT_UNKNOWN {
        return PyUnicode_FromString(ptr[u8]("unknown"));
    }
    if r == FORMAT_IEEE_LITTLE_ENDIAN {
        return PyUnicode_FromString(ptr[u8]("IEEE, little-endian"));
    }
    return PyUnicode_FromString(ptr[u8]("IEEE, big-endian"));
}

impl float_getreal(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return float_float(op);
}

impl float_getimag(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return PyFloat_FromDouble(0.0);
}

impl float___format__(op: ptr[PyObject], format_spec: ptr[PyObject]) -> ptr[PyObject] {
    if not type_has_feature(object_type(format_spec), Py_TPFLAGS_UNICODE_SUBCLASS) {
        _PyArg_BadArgument("__format__", "argument", "str", format_spec);
        return NULL;
    }
    writer = PyUnicodeWriter_Create(0);
    if not writer {
        return NULL;
    }
    if _PyFloat_FormatAdvancedWriter(
        ptr[_PyUnicodeWriter](writer),
        op,
        format_spec,
        0,
        PyUnicode_GetLength(format_spec)
    )
        == -1 {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}

impl native_little_endian -> bool {
    return (int(jacpy_float_bits(9006104071832581.0)) & 0xFF) == 0x05;
}

impl reverse_bytes(p: ptr[u8], n: i64) {
    lo = 0;
    hi = n - 1;
    while lo < hi {
        t = (p + lo).view(1)[0];
        (p + lo).view(1)[0] = (p + hi).view(1)[0];
        (p + hi).view(1)[0] = t;
        lo += 1;
        hi -= 1;
    }
}

impl must_swap(format: i64, le: i32) -> bool {
    return (format == FORMAT_IEEE_LITTLE_ENDIAN and le == i32(0))
        or (format == FORMAT_IEEE_BIG_ENDIAN and le != i32(0));
}

impl f32_from_bits(word: u32) -> f32 {
    slot = addressof(f32_slot);
    ptr[u32](slot).view(1)[0] = word;
    return ptr[f32](slot).view(1)[0];
}
