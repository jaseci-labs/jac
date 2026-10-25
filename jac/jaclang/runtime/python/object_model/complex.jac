glob:priv OK: i64 = 0,
     DOMAIN: i64 = 1,
     RANGE: i64 = 2;

import from c {
    glob:priv parse_end: ptr[u8] = ptr[u8](),
         complex_key: ptr[PyObject] = ptr[PyObject](),
         complex_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("from_number"),
                 ml_meth=ptr(complex_from_number),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "from_number($type, number, /)\n--\n\n"
                     "Convert number to a complex floating-point number."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("conjugate"),
                 ml_meth=ptr(complex_conjugate),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "conjugate($self, /)\n--\n\n"
                     "Return the complex conjugate of its argument. (3-4j).conjugate() == 3+4j."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__complex__"),
                 ml_meth=ptr(complex___complex__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__complex__($self, /)\n--\n\nConvert this value to exact type complex."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__getnewargs__"),
                 ml_meth=ptr(complex___getnewargs__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__getnewargs__($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__format__"),
                 ml_meth=ptr(complex___format__),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "__format__($self, format_spec, /)\n--\n\n"
                     "Convert to a string according to format_spec."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         complex_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("real"),
                 type_=Py_T_DOUBLE,
                 offset=PyComplexObject_REAL,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the real part of a complex number")
             ),
             PyMemberDef(
                 name=ptr[u8]("imag"),
                 type_=Py_T_DOUBLE,
                 offset=PyComplexObject_IMAG,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the imaginary part of a complex number")
             ),
             PyMemberDef()
         ],
         complex_as_number: PyNumberMethods = PyNumberMethods(
             nb_add=complex_add,
             nb_subtract=complex_sub,
             nb_multiply=complex_mul,
             nb_power=complex_pow,
             nb_negative=complex_neg,
             nb_positive=complex_pos,
             nb_absolute=complex_abs,
             nb_bool=complex_bool,
             nb_true_divide=complex_div
         ); glob PyComplex_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("complex"),
             tp_basicsize=PyComplexObject_SIZE,
             tp_repr=complex_repr,
             tp_as_number=addressof(complex_as_number),
             tp_hash=complex_hash,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "complex(real=0, imag=0)\n--\n\n"
                 "Create a complex number from a string or numbers.\n\n"
                 "If a string is given, parse it as a complex number.\n"
                 "If a single number is given, convert it to a complex number.\n"
                 "If the 'real' or 'imag' arguments are given, create a complex number\n"
                 "with the specified real and imaginary components."
             ),
             tp_richcompare=complex_richcompare,
             tp_methods=addressof(complex_methods),
             tp_members=addressof(complex_members),
             tp_alloc=PyType_GenericAlloc,
             tp_new=actual_complex_new,
             tp_free=PyObject_Free,
             tp_version_tag=_Py_TYPE_VERSION_COMPLEX
         );
}

glob:priv complex_new_signature = CallSignature(
         "complex", ["real", "imag"], 0, 2, 0, parser=PARSE_KEYWORDS
     );

def complex_of(op: ptr[PyObject]) -> ptr[PyComplexObject];

def real_of(op: ptr[PyObject]) -> f64;

def imag_of(op: ptr[PyObject]) -> f64;

def complex_check(op: ptr[PyObject]) -> bool;

def complex_check_exact(op: ptr[PyObject]) -> bool;

def new_complex(real: f64, imag: f64) -> ptr[PyObject];

def complex_subtype_from_doubles(
    type: ptr[PyTypeObject], real: f64, imag: f64
) -> ptr[PyObject];

def py_bool(value: bool) -> ptr[PyObject];

import from c {
    def cplx_prod(a: f64, b: f64, c: f64, d: f64, rr: ptr[f64], ri: ptr[f64]) {
        ac = a * c;
        bd = b * d;
        ad = a * d;
        bc = b * c;
        real = ac - bd;
        imag = ad + bc;

        if isnan(real) and isnan(imag) {
            recalc = False;
            if isinf(a) or isinf(b) {
                a = copysign(1.0 if isinf(a) else 0.0, a);
                b = copysign(1.0 if isinf(b) else 0.0, b);
                if isnan(c) {
                    c = copysign(0.0, c);
                }
                if isnan(d) {
                    d = copysign(0.0, d);
                }
                recalc = True;
            }
            if isinf(c) or isinf(d) {
                c = copysign(1.0 if isinf(c) else 0.0, c);
                d = copysign(1.0 if isinf(d) else 0.0, d);
                if isnan(a) {
                    a = copysign(0.0, a);
                }
                if isnan(b) {
                    b = copysign(0.0, b);
                }
                recalc = True;
            }
            if not recalc and (isinf(ac) or isinf(bd) or isinf(ad) or isinf(bc)) {
                if isnan(a) {
                    a = copysign(0.0, a);
                }
                if isnan(b) {
                    b = copysign(0.0, b);
                }
                if isnan(c) {
                    c = copysign(0.0, c);
                }
                if isnan(d) {
                    d = copysign(0.0, d);
                }
                recalc = True;
            }
            if recalc {
                real = infinity * (a * c - b * d);
                imag = infinity * (a * d + b * c);
            }
        }
        rr.view(1)[0] = real;
        ri.view(1)[0] = imag;
    }  def cplx_quot(
        ar: f64, ai: f64, br: f64, bi: f64, rr: ptr[f64], ri: ptr[f64]
    ) -> i64 {
        abs_breal = -br if br < 0 else br;
        abs_bimag = -bi if bi < 0 else bi;
        real = 0.0;
        imag = 0.0;
        status = OK;
        if abs_breal >= abs_bimag {
            if abs_breal == 0.0 {
                status = DOMAIN;
            } else {
                ratio = bi / br;
                denom = br + bi * ratio;
                real = (ar + ai * ratio) / denom;
                imag = (ai - ar * ratio) / denom;
            }
        } elif abs_bimag >= abs_breal {
            ratio = br / bi;
            denom = br * ratio + bi;
            real = (ar * ratio + ai) / denom;
            imag = (ai * ratio - ar) / denom;
        } else {
            real = nan;
            imag = nan;
        }

        if isnan(real) and isnan(imag) {
            if (isinf(ar) or isinf(ai)) and isfinite(br) and isfinite(bi) {
                x = copysign(1.0 if isinf(ar) else 0.0, ar);
                y = copysign(1.0 if isinf(ai) else 0.0, ai);
                real = infinity * (x * br + y * bi);
                imag = infinity * (y * br - x * bi);
            } elif (isinf(abs_breal) or isinf(abs_bimag))
                and isfinite(ar)
                and isfinite(ai) {
                x = copysign(1.0 if isinf(br) else 0.0, br);
                y = copysign(1.0 if isinf(bi) else 0.0, bi);
                real = 0.0 * (ar * x + ai * y);
                imag = 0.0 * (ai * x - ar * y);
            }
        }
        rr.view(1)[0] = real;
        ri.view(1)[0] = imag;
        return status;
    }  def cplx_rc_quot(a: f64, br: f64, bi: f64, rr: ptr[f64], ri: ptr[f64]) -> i64 {
        abs_breal = -br if br < 0 else br;
        abs_bimag = -bi if bi < 0 else bi;
        real = 0.0;
        imag = 0.0;
        status = OK;
        if abs_breal >= abs_bimag {
            if abs_breal == 0.0 {
                status = DOMAIN;
            } else {
                ratio = bi / br;
                denom = br + bi * ratio;
                real = a / denom;
                imag = (-a * ratio) / denom;
            }
        } elif abs_bimag >= abs_breal {
            ratio = br / bi;
            denom = br * ratio + bi;
            real = (a * ratio) / denom;
            imag = (-a) / denom;
        } else {
            real = nan;
            imag = nan;
        }
        if isnan(real)
            and isnan(imag)
            and isfinite(a)
            and (isinf(abs_breal) or isinf(abs_bimag)) {
            x = copysign(1.0 if isinf(br) else 0.0, br);
            y = copysign(1.0 if isinf(bi) else 0.0, bi);
            real = 0.0 * (a * x);
            imag = 0.0 * (-a * y);
        }
        rr.view(1)[0] = real;
        ri.view(1)[0] = imag;
        return status;
    }  def cplx_cr_quot(ar: f64, ai: f64, b: f64, rr: ptr[f64], ri: ptr[f64]) -> i64 {
        if b != 0.0 {
            rr.view(1)[0] = ar / b;
            ri.view(1)[0] = ai / b;
            return OK;
        }
        rr.view(1)[0] = 0.0;
        ri.view(1)[0] = 0.0;
        return DOMAIN;
    }  def cplx_pow(
        ar: f64, ai: f64, br: f64, bi: f64, rr: ptr[f64], ri: ptr[f64]
    ) -> i64 {
        if br == 0.0 and bi == 0.0 {
            rr.view(1)[0] = 1.0;
            ri.view(1)[0] = 0.0;
            return OK;
        }
        if ar == 0.0 and ai == 0.0 {
            rr.view(1)[0] = 0.0;
            ri.view(1)[0] = 0.0;
            return DOMAIN if bi != 0.0 or br < 0.0 else OK;
        }
        jacpy_set_errno(0);
        vabs = hypot(ar, ai);
        length = pow(vabs, br);
        at = atan2(ai, ar);
        phase = at * br;
        if bi != 0.0 {
            length *= exp(-at * bi);
            phase += bi * log(vabs);
        }
        real = length * cos(phase);
        imag = length * sin(phase);
        errno = jacpy_errno();
        status = RANGE if errno == ERANGE else (DOMAIN if errno == EDOM else OK);
        rr.view(1)[0] = real;
        ri.view(1)[0] = imag;
        return adjust_erange2(real, imag, status);
    }  def cplx_powu(xr: f64, xi: f64, n: i64, rr: ptr[f64], ri: ptr[f64]) {
        real = 1.0;
        imag = 0.0;
        pr = xr;
        pi = xi;
        mask = i64(1);
        while mask > 0 and n >= mask {
            if (n & mask) != 0 {
                cplx_prod(real, imag, pr, pi, &mut real, &mut imag);
            }
            mask = wrapping_shl(mask, i64(1));
            cplx_prod(pr, pi, pr, pi, &mut pr, &mut pi);
        }
        rr.view(1)[0] = real;
        ri.view(1)[0] = imag;
    }  def cplx_powi(xr: f64, xi: f64, n: i64, rr: ptr[f64], ri: ptr[f64]) -> i64 {
        if n > 0 {
            cplx_powu(xr, xi, n, rr, ri);
            return OK;
        }
        ur = 0.0;
        ui = 0.0;
        cplx_powu(xr, xi, -n, &mut ur, &mut ui);
        return cplx_quot(1.0, 0.0, ur, ui, rr, ri);
    }  def cplx_abs(zr: f64, zi: f64, status: ptr[i64]) -> f64 {
        status.view(1)[0] = OK;
        if not isfinite(zr) or not isfinite(zi) {
            if isinf(zr) {
                return fabs(zr);
            }
            if isinf(zi) {
                return fabs(zi);
            }

            return nan;
        }
        result = hypot(zr, zi);
        if not isfinite(result) {
            status.view(1)[0] = RANGE;
        }
        return result;
    }
}

def adjust_erange2(x: f64, y: f64, status: i64) -> i64;

def set_status_errno(status: i64);

import from c {
    def _Py_c_sum(a: Py_complex, b: Py_complex) -> Py_complex {
        return Py_complex(real=a.real + b.real, imag=a.imag + b.imag);
    }  def _Py_cr_sum(a: Py_complex, b: f64) -> Py_complex {
        return Py_complex(real=a.real + b, imag=a.imag);
    }  def _Py_c_diff(a: Py_complex, b: Py_complex) -> Py_complex {
        return Py_complex(real=a.real - b.real, imag=a.imag - b.imag);
    }  def _Py_cr_diff(a: Py_complex, b: f64) -> Py_complex {
        return Py_complex(real=a.real - b, imag=a.imag);
    }  def _Py_rc_diff(a: f64, b: Py_complex) -> Py_complex {
        return Py_complex(real=a - b.real, imag=-b.imag);
    }  def _Py_c_neg(a: Py_complex) -> Py_complex {
        return Py_complex(real=-a.real, imag=-a.imag);
    }  def _Py_c_prod(z: Py_complex, w: Py_complex) -> Py_complex {
        rr = 0.0;
        ri = 0.0;
        cplx_prod(z.real, z.imag, w.real, w.imag, &mut rr, &mut ri);
        return Py_complex(real=rr, imag=ri);
    }  def _Py_cr_prod(a: Py_complex, b: f64) -> Py_complex {
        return Py_complex(real=a.real * b, imag=a.imag * b);
    }  def _Py_c_quot(a: Py_complex, b: Py_complex) -> Py_complex {
        rr = 0.0;
        ri = 0.0;
        status = cplx_quot(a.real, a.imag, b.real, b.imag, &mut rr, &mut ri);
        if status == DOMAIN {
            jacpy_set_errno(EDOM);
        }
        return Py_complex(real=rr, imag=ri);
    }  def _Py_cr_quot(a: Py_complex, b: f64) -> Py_complex {
        rr = 0.0;
        ri = 0.0;
        status = cplx_cr_quot(a.real, a.imag, b, &mut rr, &mut ri);
        if status == DOMAIN {
            jacpy_set_errno(EDOM);
        }
        return Py_complex(real=rr, imag=ri);
    }  def _Py_rc_quot(a: f64, b: Py_complex) -> Py_complex {
        rr = 0.0;
        ri = 0.0;
        status = cplx_rc_quot(a, b.real, b.imag, &mut rr, &mut ri);
        if status == DOMAIN {
            jacpy_set_errno(EDOM);
        }
        return Py_complex(real=rr, imag=ri);
    }  def _Py_c_pow(a: Py_complex, b: Py_complex) -> Py_complex {
        rr = 0.0;
        ri = 0.0;
        status = cplx_pow(a.real, a.imag, b.real, b.imag, &mut rr, &mut ri);
        if status != OK {
            set_status_errno(status);
        }
        return Py_complex(real=rr, imag=ri);
    }  def _Py_c_abs(z: Py_complex) -> f64 {
        status = OK;
        result = cplx_abs(z.real, z.imag, &mut status);
        if not isnan(result) {
            set_status_errno(status);
        }
        return result;
    }  def PyComplex_FromCComplex(cval: Py_complex) -> ptr[PyObject] {
        return new_complex(cval.real, cval.imag);
    }  def PyComplex_FromDoubles(real: f64, imag: f64) -> ptr[PyObject] {
        return new_complex(real, imag);
    }  def PyComplex_RealAsDouble(op: ptr[PyObject]) -> f64 {
        if complex_check(op) {
            return real_of(op);
        }
        newop = try_complex_special_method(op);
        if newop {
            real = real_of(newop);
            jacpy_release(newop);
            return real;
        }
        if not PyErr_Occurred() {
            return PyFloat_AsDouble(op);
        }
        return -1.0;
    }  def PyComplex_ImagAsDouble(op: ptr[PyObject]) -> f64 {
        if complex_check(op) {
            return imag_of(op);
        }
        newop = try_complex_special_method(op);
        if newop {
            imag = imag_of(newop);
            jacpy_release(newop);
            return imag;
        }
        if not PyErr_Occurred() {
            PyFloat_AsDouble(op);
            if not PyErr_Occurred() {
                return 0.0;
            }
        }
        return -1.0;
    }  def PyComplex_AsCComplex(op: ptr[PyObject]) -> Py_complex {
        real = 0.0;
        imag = 0.0;
        cplx_value(op, &mut real, &mut imag);
        return Py_complex(real=real, imag=imag);
    }  def cplx_value(op: ptr[PyObject], rr: ptr[f64], ri: ptr[f64]) {
        ri.view(1)[0] = 0.0;

        if complex_check(op) {
            rr.view(1)[0] = real_of(op);
            ri.view(1)[0] = imag_of(op);
            return;
        }

        newop = try_complex_special_method(op);
        if newop {
            rr.view(1)[0] = real_of(newop);
            ri.view(1)[0] = imag_of(newop);
            jacpy_release(newop);
            return;
        }
        if PyErr_Occurred() {
            rr.view(1)[0] = -1.0;
            return;
        }

        rr.view(1)[0] = PyFloat_AsDouble(op);
    }  def cplx_real_value(op: ptr[PyObject], value: ptr[f64]) -> i32 {
        if jacpy_is_float(op) != 0 {
            value.view(1)[0] = ptr[PyFloatObject](op).view(1)[0].ob_fval;
            return i32(1);
        }
        if jacpy_is_long(op) != 0 {
            result = PyLong_AsDouble(op);
            if result == -1.0 and PyErr_Occurred() {
                return i32(-1);
            }
            value.view(1)[0] = result;
            return i32(1);
        }
        return i32(0);
    }  def cplx_operand(op: ptr[PyObject], rr: ptr[f64], ri: ptr[f64]) -> i32 {
        if complex_check(op) {
            rr.view(1)[0] = real_of(op);
            ri.view(1)[0] = imag_of(op);
            return i32(1);
        }
        ri.view(1)[0] = 0.0;
        return cplx_real_value(op, rr);
    }
}

def operand_failure(status: i32) -> ptr[PyObject];

def try_complex_special_method(op: ptr[PyObject]) -> ptr[PyObject];

def complex_repr(op: ptr[PyObject]) -> ptr[PyObject];

def complex_hash(op: ptr[PyObject]) -> i64;

glob:priv ADD: int = 0,
     SUB: int = 1,
     MUL: int = 2,
     DIV: int = 3;

def complex_binop(v: ptr[PyObject], w: ptr[PyObject], operation: int) -> ptr[PyObject];

def complex_add(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def complex_sub(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def complex_mul(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def complex_div(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject];

def complex_pow(v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]) -> ptr[PyObject];

def complex_neg(op: ptr[PyObject]) -> ptr[PyObject];

def complex_pos(op: ptr[PyObject]) -> ptr[PyObject];

def complex_abs(op: ptr[PyObject]) -> ptr[PyObject];

def complex_bool(op: ptr[PyObject]) -> i32;

def complex_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject];

def complex_conjugate(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def complex___getnewargs__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def complex___format__(op: ptr[PyObject], format_spec: ptr[PyObject]) -> ptr[PyObject];

def complex___complex__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def is_space(c: u8) -> bool;

def complex_from_string_inner(s: ptr[u8], length: i64, type: ptr) -> ptr[PyObject];

def read_double(s: ptr[u8]) -> tuple[f64, ptr[u8], bool];

def complex_subtype_from_string(
    type: ptr[PyTypeObject], v: ptr[PyObject]
) -> ptr[PyObject];

def actual_complex_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def is_real_number(op: ptr[PyObject]) -> bool;

def complex_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def complex_new_bound(args: BoundArguments) -> ptr[PyObject];

def complex_new_impl(
    type: ptr[PyTypeObject], r: ptr[PyObject], i: ptr[PyObject]
) -> ptr[PyObject];

def zero_object -> ptr[PyObject];

def complex_from_number(cls: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject];

impl complex_of(op: ptr[PyObject]) -> ptr[PyComplexObject] {
    return ptr[PyComplexObject](op);
}

impl real_of(op: ptr[PyObject]) -> f64 {
    return complex_of(op).view(1)[0].cval.real;
}

impl imag_of(op: ptr[PyObject]) -> f64 {
    return complex_of(op).view(1)[0].cval.imag;
}

impl complex_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, addressof(PyComplex_Type));
}

impl complex_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyComplex_Type));
}

impl new_complex(real: f64, imag: f64) -> ptr[PyObject] {
    op = ptr[PyObject](PyObject_Malloc(u64(PyComplexObject_SIZE)));
    if not op {
        return PyErr_NoMemory();
    }
    PyObject_Init(op, ptr[PyObject](addressof(PyComplex_Type)));
    complex_of(op).view(1)[0].cval.real = real;
    complex_of(op).view(1)[0].cval.imag = imag;
    return op;
}

impl complex_subtype_from_doubles(
    type: ptr[PyTypeObject], real: f64, imag: f64
) -> ptr[PyObject] {
    op = type.view(1)[0].tp_alloc(type, 0);
    if op {
        complex_of(op).view(1)[0].cval.real = real;
        complex_of(op).view(1)[0].cval.imag = imag;
    }
    return op;
}

impl py_bool(value: bool) -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct))
        if value
        else ptr[PyObject](addressof(_Py_FalseStruct));
}

impl adjust_erange2(x: f64, y: f64, status: i64) -> i64 {
    if isinf(x) or isinf(y) {
        return RANGE if status == OK else status;
    }
    return OK if status == RANGE else status;
}

impl set_status_errno(status: i64) {
    jacpy_set_errno(EDOM if status == DOMAIN else (ERANGE if status == RANGE else 0));
}

impl operand_failure(status: i32) -> ptr[PyObject] {
    return Py_NewRef(Py_NotImplemented) if status == 0 else NULL;
}

impl try_complex_special_method(op: ptr[PyObject]) -> ptr[PyObject] {
    if not complex_key {
        complex_key = PyUnicode_InternFromString(ptr[u8]("__complex__"));
        if not complex_key {
            return NULL;
        }
    }
    f = _PyObject_LookupSpecial(op, complex_key);
    if not f {
        return NULL;
    }
    res = PyObject_CallNoArgs(f);
    jacpy_release(f);
    if not res or complex_check_exact(res) {
        return res;
    }
    type_name = object_type(res).view(1)[0].tp_name;
    if not complex_check(res) {
        PyErr_Format(
            PyExc_TypeError, "__complex__ returned non-complex (type %.200s)", type_name
        );
        jacpy_release(res);
        return NULL;
    }

    if PyErr_WarnFormat(
        PyExc_DeprecationWarning,
        1,
        "__complex__ returned non-complex (type %.200s).  The ability to return an instance of a strict subclass of complex is deprecated, and may be removed in a future version of Python.",
        type_name
    )
        != 0 {
        jacpy_release(res);
        return NULL;
    }
    return res;
}

impl complex_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    real = real_of(op);
    imag = imag_of(op);
    result = NULL;
    pre = ptr[u8]();
    im = ptr[u8]();
    if real == 0.0 and copysign(1.0, real) == 1.0 {
        im = PyOS_double_to_string(imag, i8(114), 0, 0, None);
        if not im {
            PyErr_NoMemory();
        } else {
            result = PyUnicode_FromFormat(
                "%s%s%sj%s", ptr[u8](""), ptr[u8](""), im, ptr[u8]("")
            );
        }
    } else {
        pre = PyOS_double_to_string(real, i8(114), 0, 0, None);
        if not pre {
            PyErr_NoMemory();
        } else {
            im = PyOS_double_to_string(imag, i8(114), 0, Py_DTSF_SIGN, None);
            if not im {
                PyErr_NoMemory();
            } else {
                result = PyUnicode_FromFormat(
                    "%s%s%sj%s", ptr[u8]("("), pre, im, ptr[u8](")")
                );
            }
        }
    }
    PyMem_Free(ptr(im));
    PyMem_Free(ptr(pre));
    return result;
}

impl complex_hash(op: ptr[PyObject]) -> i64 {
    hashreal = u64.wrap(_Py_HashDouble(op, real_of(op)));
    if hashreal == u64.MAX {
        return -1;
    }
    hashimag = u64.wrap(_Py_HashDouble(op, imag_of(op)));
    if hashimag == u64.MAX {
        return -1;
    }

    combined = wrapping_add(hashreal, wrapping_mul(PyHASH_IMAG, hashimag));
    if combined == u64.MAX {
        combined = u64.MAX - u64(1);
    }
    return i64.wrap(combined);
}

impl complex_binop(
    v: ptr[PyObject], w: ptr[PyObject], operation: int
) -> ptr[PyObject] {
    rr = 0.0;
    ri = 0.0;
    status = OK;
    if complex_check(w) {
        br = real_of(w);
        bi = imag_of(w);
        if complex_check(v) {
            ar = real_of(v);
            ai = imag_of(v);
            if operation == ADD {
                rr = ar + br;
                ri = ai + bi;
            } elif operation == SUB {
                rr = ar - br;
                ri = ai - bi;
            } elif operation == MUL {
                cplx_prod(ar, ai, br, bi, &mut rr, &mut ri);
            } else {
                status = cplx_quot(ar, ai, br, bi, &mut rr, &mut ri);
            }
        } else {
            a = 0.0;
            found = cplx_real_value(v, &mut a);
            if found != 1 {
                return operand_failure(found);
            }
            if operation == ADD {
                rr = a + br;
                ri = bi;
            } elif operation == SUB {
                rr = a - br;
                ri = -bi;
            } elif operation == MUL {
                rr = br * a;
                ri = bi * a;
            } else {
                status = cplx_rc_quot(a, br, bi, &mut rr, &mut ri);
            }
        }
    } elif not complex_check(v) {
        return Py_NewRef(Py_NotImplemented);
    } else {
        ar = real_of(v);
        ai = imag_of(v);
        b = 0.0;
        found = cplx_real_value(w, &mut b);
        if found != 1 {
            return operand_failure(found);
        }
        if operation == ADD {
            rr = ar + b;
            ri = ai;
        } elif operation == SUB {
            rr = ar - b;
            ri = ai;
        } elif operation == MUL {
            rr = ar * b;
            ri = ai * b;
        } else {
            status = cplx_cr_quot(ar, ai, b, &mut rr, &mut ri);
        }
    }
    if status == DOMAIN {
        PyErr_SetString(PyExc_ZeroDivisionError, "division by zero");
        return NULL;
    }
    return new_complex(rr, ri);
}

impl complex_add(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    return complex_binop(v, w, ADD);
}

impl complex_sub(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    return complex_binop(v, w, SUB);
}

impl complex_mul(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    return complex_binop(v, w, MUL);
}

impl complex_div(v: ptr[PyObject], w: ptr[PyObject]) -> ptr[PyObject] {
    return complex_binop(v, w, DIV);
}

impl complex_pow(
    v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
) -> ptr[PyObject] {
    ar = 0.0;
    ai = 0.0;
    found = cplx_operand(v, &mut ar, &mut ai);
    if found != 1 {
        return operand_failure(found);
    }
    br = 0.0;
    bi = 0.0;
    found = cplx_operand(w, &mut br, &mut bi);
    if found != 1 {
        return operand_failure(found);
    }
    if z != Py_None {
        PyErr_SetString(PyExc_ValueError, "complex modulo");
        return NULL;
    }
    rr = 0.0;
    ri = 0.0;
    status = OK;

    if bi == 0.0 and br == floor(br) and fabs(br) <= 100.0 {
        status = cplx_powi(ar, ai, i64(br), &mut rr, &mut ri);
        status = adjust_erange2(rr, ri, status);
    } else {
        status = cplx_pow(ar, ai, br, bi, &mut rr, &mut ri);
    }
    if status == DOMAIN {
        PyErr_SetString(PyExc_ZeroDivisionError, "zero to a negative or complex power");
        return NULL;
    } elif status == RANGE {
        PyErr_SetString(PyExc_OverflowError, "complex exponentiation");
        return NULL;
    }
    return new_complex(rr, ri);
}

impl complex_neg(op: ptr[PyObject]) -> ptr[PyObject] {
    return new_complex(-real_of(op), -imag_of(op));
}

impl complex_pos(op: ptr[PyObject]) -> ptr[PyObject] {
    if complex_check_exact(op) {
        return Py_NewRef(op);
    }
    return new_complex(real_of(op), imag_of(op));
}

impl complex_abs(op: ptr[PyObject]) -> ptr[PyObject] {
    status = OK;
    result = cplx_abs(real_of(op), imag_of(op), &mut status);
    if status == RANGE {
        PyErr_SetString(PyExc_OverflowError, "absolute value too large");
        return NULL;
    }
    return PyFloat_FromDouble(result);
}

impl complex_bool(op: ptr[PyObject]) -> i32 {
    return i32(real_of(op) != 0.0 or imag_of(op) != 0.0);
}

impl complex_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if op != Py_EQ and op != Py_NE {
        return Py_NewRef(Py_NotImplemented);
    }
    ir = 0.0;
    ii = 0.0;
    found = cplx_operand(v, &mut ir, &mut ii);
    if found != 1 {
        return operand_failure(found);
    }
    equal = False;
    if jacpy_is_long(w) != 0 {
        if ii == 0.0 {
            j = PyFloat_FromDouble(ir);
            if not j {
                return NULL;
            }
            sub_res = PyObject_RichCompare(j, w, op);
            jacpy_release(j);
            return sub_res;
        }
    } elif jacpy_is_float(w) != 0 {
        equal = ir == PyFloat_AsDouble(w) and ii == 0.0;
    } elif complex_check(w) {
        equal = ir == real_of(w) and ii == imag_of(w);
    } else {
        return Py_NewRef(Py_NotImplemented);
    }
    return py_bool(equal == (op == Py_EQ));
}

impl complex_conjugate(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return new_complex(real_of(op), -imag_of(op));
}

impl complex___getnewargs__(
    op: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_BuildValue("(dd)", real_of(op), imag_of(op));
}

impl complex___format__(
    op: ptr[PyObject], format_spec: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_unicode(format_spec) == 0 {
        _PyArg_BadArgument("__format__", "argument", "str", format_spec);
        return NULL;
    }
    writer = PyUnicodeWriter_Create(0);
    if not writer {
        return NULL;
    }
    if _PyComplex_FormatAdvancedWriter(
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

impl complex___complex__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    if complex_check_exact(op) {
        return Py_NewRef(op);
    }
    return new_complex(real_of(op), imag_of(op));
}

impl is_space(c: u8) -> bool {
    return c == 32 or (c >= 9 and c <= 13);
}

impl complex_from_string_inner(s: ptr[u8], length: i64, type: ptr) -> ptr[PyObject] {
    x = 0.0;
    y = 0.0;
    start = s;

    while is_space(s.view(1)[0]) {
        s += 1;
    }
    got_bracket = False;
    if s.view(1)[0] == 40 {
        got_bracket = True;
        s += 1;
        while is_space(s.view(1)[0]) {
            s += 1;
        }
    }

    (z, end, failed) = read_double(s);
    if failed {
        return NULL;
    }
    malformed = False;
    if end != s {
        s = end;
        c = s.view(1)[0];
        if c == 43 or c == 45 {
            x = z;
            (y, end, failed) = read_double(s);
            if failed {
                return NULL;
            }
            if end != s {
                s = end;
            } else {
                y = 1.0 if s.view(1)[0] == 43 else -1.0;
                s += 1;
            }
            if not (s.view(1)[0] == 106 or s.view(1)[0] == 74) {
                malformed = True;
            } else {
                s += 1;
            }
        } elif c == 106 or c == 74 {
            s += 1;
            y = z;
        } else {
            x = z;
        }
    } else {
        c = s.view(1)[0];
        if c == 43 or c == 45 {
            y = 1.0 if c == 43 else -1.0;
            s += 1;
        } else {
            y = 1.0;
        }
        if not (s.view(1)[0] == 106 or s.view(1)[0] == 74) {
            malformed = True;
        } else {
            s += 1;
        }
    }
    if not malformed {
        while is_space(s.view(1)[0]) {
            s += 1;
        }
        if got_bracket {
            if s.view(1)[0] != 41 {
                malformed = True;
            } else {
                s += 1;
                while is_space(s.view(1)[0]) {
                    s += 1;
                }
            }
        }
    }

    if malformed or s - start != length {
        PyErr_SetString(PyExc_ValueError, "complex() arg is a malformed string");
        return NULL;
    }
    return complex_subtype_from_doubles(ptr[PyTypeObject](type), x, y);
}

impl read_double(s: ptr[u8]) -> tuple[f64, ptr[u8], bool] {
    end_slot = addressof(parse_end);
    value = PyOS_string_to_double(s, ptr(end_slot), NULL);
    end = end_slot.view(1)[0];
    if value == -1.0 and PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_ValueError) != 0 {
            PyErr_Clear();
        } else {
            return (value, end, True);
        }
    }
    return (value, end, False);
}

impl complex_subtype_from_string(
    type: ptr[PyTypeObject], v: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_unicode(v) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "complex() argument must be a string or a number, not %T",
            v
        );
        return NULL;
    }
    s_buffer = _PyUnicode_TransformDecimalAndSpaceToASCII(v);
    if not s_buffer {
        return NULL;
    }

    length = i64(0);
    s = PyUnicode_AsUTF8AndSize(s_buffer, &mut length);
    result = _Py_string_to_number_with_underscores(
        s, length, ptr[u8]("complex"), v, ptr(type), ptr(complex_from_string_inner)
    );
    jacpy_release(s_buffer);
    return result;
}

impl actual_complex_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = object_size(args);
    if nargs > 1 or (kwargs and object_size(kwargs) != 0) {
        return complex_new(type, args, kwargs);
    }
    if nargs == 0 {
        return complex_subtype_from_doubles(type, 0.0, 0.0);
    }
    arg = tuple_get_item(args, 0);

    if complex_check_exact(arg) and type == addressof(PyComplex_Type) {
        return Py_NewRef(arg);
    }
    if jacpy_is_unicode(arg) != 0 {
        return complex_subtype_from_string(type, arg);
    }
    tmp = try_complex_special_method(arg);
    if tmp {
        res = complex_subtype_from_doubles(type, real_of(tmp), imag_of(tmp));
        jacpy_release(tmp);
        return res;
    }
    if PyErr_Occurred() {
        return NULL;
    }
    if complex_check(arg) {
        return complex_subtype_from_doubles(type, real_of(arg), imag_of(arg));
    }
    if is_real_number(arg) {
        r = PyFloat_AsDouble(arg);
        if r != -1.0 or not PyErr_Occurred() {
            return complex_subtype_from_doubles(type, r, 0.0);
        }
        return NULL;
    }
    PyErr_Format(
        PyExc_TypeError, "complex() argument must be a string or a number, not %T", arg
    );
    return NULL;
}

impl is_real_number(op: ptr[PyObject]) -> bool {
    nb = object_type(op).view(1)[0].tp_as_number;
    return bool(nb)
        and (int(nb.view(1)[0].nb_float) != 0 or int(nb.view(1)[0].nb_index) != 0);
}

impl complex_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwargs {
        nargs = object_size(args);
        if nargs <= 2 {
            r = tuple_get_item(args, 0) if nargs > 0 else NULL;
            i = tuple_get_item(args, 1) if nargs > 1 else NULL;
            return complex_new_impl(type, r, i);
        }
    }
    return invoke(
        complex_new_signature, args, kwargs, complex_new_bound, ptr[PyObject](type)
    );
}

impl complex_new_bound(args: BoundArguments) -> ptr[PyObject] {
    return complex_new_impl(
        ptr[PyTypeObject](args.context), args.values[0], args.values[1]
    );
}

impl complex_new_impl(
    type: ptr[PyTypeObject], r: ptr[PyObject], i: ptr[PyObject]
) -> ptr[PyObject] {
    if not r {
        r = zero_object();
    }
    orig_r = r;
    own_r = False;

    tmp = try_complex_special_method(r);
    if tmp {
        r = tmp;
        own_r = True;
    } elif PyErr_Occurred() {
        return NULL;
    }
    if not is_real_number(r) and not complex_check(r) {
        PyErr_Format(
            PyExc_TypeError,
            "complex() argument 'real' must be a real number, not %T",
            r
        );
        if own_r {
            jacpy_release(r);
        }
        return NULL;
    }
    if i and not is_real_number(i) and not complex_check(i) {
        PyErr_Format(
            PyExc_TypeError,
            "complex() argument 'imag' must be a real number, not %T",
            i
        );
        if own_r {
            jacpy_release(r);
        }
        return NULL;
    }

    cr_real = 0.0;
    cr_imag = 0.0;
    cr_is_complex = False;
    if complex_check(r) {
        cr_real = real_of(r);
        cr_imag = imag_of(r);
        cr_is_complex = True;
        if own_r {
            jacpy_release(r);
        }
        if not is_real_number(orig_r)
            and PyErr_WarnFormat(
                PyExc_DeprecationWarning,
                1,
                "complex() argument 'real' must be a real number, not %T",
                orig_r
            )
                != 0 {
            return NULL;
        }
    } else {
        value = PyNumber_Float(r);
        if not value {
            return NULL;
        }
        cr_real = PyFloat_AsDouble(value);
        jacpy_release(value);
    }
    ci_real = 0.0;
    ci_imag = 0.0;
    ci_is_complex = False;
    if not i {
        ci_real = cr_imag;
    } elif complex_check(i) {
        if PyErr_WarnFormat(
            PyExc_DeprecationWarning,
            1,
            "complex() argument 'imag' must be a real number, not %T",
            i
        )
            != 0 {
            return NULL;
        }
        ci_real = real_of(i);
        ci_imag = imag_of(i);
        ci_is_complex = True;
    } else {
        value = PyNumber_Float(i);
        if not value {
            return NULL;
        }
        ci_real = PyFloat_AsDouble(value);
        jacpy_release(value);
    }

    if ci_is_complex {
        cr_real -= ci_imag;
    }
    if cr_is_complex and i {
        ci_real += cr_imag;
    }
    return complex_subtype_from_doubles(type, cr_real, ci_real);
}

impl zero_object -> ptr[PyObject] {
    zero = PyLong_FromLong(0);
    jacpy_release(zero);
    return zero;
}

impl complex_from_number(cls: ptr[PyObject], number: ptr[PyObject]) -> ptr[PyObject] {
    type = ptr[PyTypeObject](cls);
    if complex_check_exact(number) and type == addressof(PyComplex_Type) {
        return Py_NewRef(number);
    }
    real = 0.0;
    imag = 0.0;
    cplx_value(number, &mut real, &mut imag);
    if real == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    result = new_complex(real, imag);
    if type != addressof(PyComplex_Type) and result {
        converted = PyObject_CallOneArg(cls, result);
        jacpy_release(result);
        result = converted;
    }
    return result;
}
