impl PyObj.nb_binop(kind: int, other: PyObj) -> PyObj {
    return py_error("TypeError", "unsupported operand types");
}

impl PyObj.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if kind == 2 {
        return PyBool(t="bool", val=self is other);
    }
    if kind == 3 {
        return PyBool(t="bool", val=self is not other);
    }
    return PY_NOT_IMPLEMENTED;
}

impl PyObj.mp_subscript(index: PyObj) -> PyObj {
    return py_error("TypeError", "object is not subscriptable");
}

impl PyObj.mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
    return py_error("TypeError", "object does not support item assignment");
}

impl PyObj.mp_del_subscript(index: PyObj) -> PyObj {
    return py_error("TypeError", "object does not support item deletion");
}

impl PyObj.tp_iter -> PyObj {
    return py_error("TypeError", "object is not iterable");
}

impl PyObj.tp_bool -> bool {
    return True;
}

impl PyObj.tp_getattro(name: str) -> PyObj {
    return py_error("AttributeError", name);
}

impl PyObj.tp_setattro(name: str, value: PyObj) -> PyObj {
    return py_error("AttributeError", name);
}

impl PyObj.tp_del_attr(name: str) -> PyObj {
    return py_error("AttributeError", name);
}

impl PyObj.tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    return py_error("TypeError", "object is not callable");
}

impl PyObj.tp_hashkey -> PyObj {
    return py_error("TypeError", "unhashable type");
}

impl PyObj.tp_type_name -> str {
    return self.t;
}

impl PyObj.to_index -> PyObj {
    return py_error("TypeError", "object cannot be interpreted as an integer");
}

impl int_true_divide(av: int, bv: int) -> PyObj {
    DBL_MAX_EXP = 1024;
    DBL_MIN_EXP = -1021;
    DBL_MANT_DIG = 53;
    DBL_MIN_OVERFLOW = 2 ** DBL_MAX_EXP - 2 ** (DBL_MAX_EXP - DBL_MANT_DIG - 1);
    if bv == 0 {
        return py_error("ZeroDivisionError", "division by zero");
    }
    negative = (av < 0) != (bv < 0);
    a = av;
    b = bv;
    if a < 0 {
        a = -a;
    }
    if b < 0 {
        b = -b;
    }
    if a >= DBL_MIN_OVERFLOW * b {
        return py_error(
            "OverflowError", "integer division result too large for a float"
        );
    }
    d = a.bit_length() - b.bit_length();
    if (d >= 0 and a >= 2 ** d * b) or (d < 0 and a * 2 ** (-d) >= b) {
        d = d + 1;
    }
    exp = d;
    if exp < DBL_MIN_EXP {
        exp = DBL_MIN_EXP;
    }
    exp = exp - DBL_MANT_DIG;
    aa = a;
    bb = b;
    if exp < 0 {
        aa = aa << -exp;
    } else {
        bb = bb << exp;
    }
    q = aa // bb;
    r = aa % bb;
    r2 = r + r;
    if r2 > bb or (r2 == bb and q % 2 == 1) {
        q = q + 1;
    }
    result = float(q);
    scale = 2.0 ** exp;
    result = result * scale;
    if negative {
        result = -result;
    }
    return PyFloat(t="float", val=result);
}

impl PyInt.to_index -> PyObj {
    return self;
}

impl PyInt.nb_binop(kind: int, other: PyObj) -> PyObj {
    if other.t != "int" {
        return py_error("TypeError", "unsupported operand types");
    }
    b = (other as PyInt).val;
    a = self.val;
    if kind == NB_ADD {
        return PyInt(t="int", val=a + b);
    }
    if kind == NB_MULTIPLY {
        return PyInt(t="int", val=a * b);
    }
    if kind == NB_REMAINDER {
        if b == 0 {
            return py_error("ZeroDivisionError", "division by zero");
        }
        return PyInt(t="int", val=a % b);
    }
    if kind == NB_SUBTRACT {
        return PyInt(t="int", val=a - b);
    }
    if kind == NB_AND {
        return PyInt(t="int", val=a & b);
    }
    if kind == NB_FLOOR_DIVIDE {
        if b == 0 {
            return py_error("ZeroDivisionError", "division by zero");
        }
        return PyInt(t="int", val=a // b);
    }
    if kind == NB_OR {
        return PyInt(t="int", val=a | b);
    }

    if kind == NB_TRUE_DIVIDE {
        return int_true_divide(a, b);
    }
    if kind == NB_XOR {
        return PyInt(t="int", val=a ^ b);
    }
    if kind == NB_LSHIFT {
        if b < 0 {
            return py_error("ValueError", "negative shift count");
        }

        if a == 0 {
            return PyInt(t="int", val=0);
        }
        return PyInt(t="int", val=a << b);
    }
    if kind == NB_RSHIFT {
        if b < 0 {
            return py_error("ValueError", "negative shift count");
        }
        return PyInt(t="int", val=a >> b);
    }
    if kind == NB_POWER {
        if b < 0 {
            if a == 0 {
                return py_error("ZeroDivisionError", "zero to a negative power");
            }
            return PyFloat(t="float", val=float(a) ** float(b));
        }
        return PyInt(t="int", val=(a ** b) as int);
    }
    return py_error("TypeError", "unsupported operand types");
}

impl PyInt.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if other.t != "int" and other.t != "bool" and other.t != "float" {
        idxr = other.to_index();
        if not is_error(idxr) and (idxr.t == "int" or idxr.t == "bool") {
            other = idxr;
        }
    }

    if other.t == "int" or other.t == "bool" {
        a = self.val;
        b = 0;
        if other.t == "int" {
            b = (other as PyInt).val;
        } elif (other as PyBool).val {
            b = 1;
        }
        return _bool_from_cmp(_cmp3(a, b), kind);
    }

    if other.t == "float" {
        of = other as PyFloat;
        if of.val == float("inf") {
            return _bool_from_cmp(-1, kind);
        }
        if of.val == float("-inf") {
            return _bool_from_cmp(1, kind);
        }
        if of.val != of.val {
            return of.tp_richcompare(kind, self);
        }

        return _bool_from_cmp(_cmp_int_vs_float(self.val, of.val), kind);
    }

    if kind == 2 {
        return PyBool(t="bool", val=False);
    }
    if kind == 3 {
        return PyBool(t="bool", val=True);
    }
    return PY_NOT_IMPLEMENTED;
}

impl PyInt.tp_bool -> bool {
    return self.val != 0;
}

impl PyInt.tp_hashkey -> PyObj {
    return PyStr(t="str", val="n:" + str(self.val));
}

impl PyInt.tp_getattro(name: str) -> PyObj {
    return _number_getattro(name, self.val);
}

impl PyStr.nb_binop(kind: int, other: PyObj) -> PyObj {
    if kind == NB_ADD and other.t == "str" {
        return PyStr(t="str", val=self.val + (other as PyStr).val);
    }
    if kind == NB_REMAINDER {
        return str_mod_format(self.val, other);
    }
    return py_error("TypeError", "unsupported operand types");
}

impl PyStr.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if other.t != "str" {
        if kind == 2 {
            return PyBool(t="bool", val=False);
        }
        if kind == 3 {
            return PyBool(t="bool", val=True);
        }
        return PY_NOT_IMPLEMENTED;
    }
    a = self.val;
    b = (other as PyStr).val;
    return _bool_from_cmp(_cmp3_str(a, b), kind);
}

impl PyStr.mp_subscript(index: PyObj) -> PyObj {
    if isinstance(index, PySlice) {
        err = _zero_step_error(index as PySlice);
        if is_error(err) {
            return err;
        }
        return PyStr(t="str", val=_slice_str(self.val, index as PySlice));
    }
    pos = _seq_index(
        index,
        len(self.val),
        "string indices must be integers or slices",
        "string index out of range",
    );
    if is_error(pos) {
        return pos;
    }
    return PyStr(t="str", val=self.val[(pos as PyInt).val]);
}

impl PyStr.tp_iter -> PyObj {
    chars: list[PyObj] = [];
    for ch in self.val {
        chars.append(PyStr(t="str", val=ch));
    }
    return PyIter(t="iter", items=chars, index=0);
}

impl PyStr.tp_bool -> bool {
    return len(self.val) != 0;
}

impl PyStr.tp_hashkey -> PyObj {
    return PyStr(t="str", val="s:" + self.val);
}

impl PyBytes.mp_subscript(index: PyObj) -> PyObj {
    if isinstance(index, PySlice) {
        err = _zero_step_error(index as PySlice);
        if is_error(err) {
            return err;
        }
        return PyBytes(t="bytes", val=_slice_ints(self.val, index as PySlice));
    }
    pos = _seq_index(
        index,
        len(self.val),
        "bytes indices must be integers or slices",
        "index out of range",
    );
    if is_error(pos) {
        return pos;
    }
    return PyInt(t="int", val=self.val[(pos as PyInt).val]);
}

impl PyBytes.tp_iter -> PyObj {
    items: list[PyObj] = [];
    for v in self.val {
        items.append(PyInt(t="int", val=v));
    }
    return PyIter(t="iter", items=items, index=0);
}

impl PyBytes.tp_bool -> bool {
    return len(self.val) != 0;
}

impl PyBytes.tp_hashkey -> PyObj {
    key = "b:";
    for v in self.val {
        key = key + str(v) + ",";
    }
    return PyStr(t="str", val=key);
}

impl _number_getattro(name: str, real: int) -> PyObj {
    if name == "real" or name == "numerator" {
        return PyInt(t="int", val=real);
    }
    if name == "imag" {
        return PyInt(t="int", val=0);
    }
    if name == "denominator" {
        return PyInt(t="int", val=1);
    }
    return py_error("AttributeError", name);
}

impl PyFloat._coerce(other: PyObj) -> tuple[bool, float] {
    if other.t == "float" {
        return (True, (other as PyFloat).val);
    }
    if other.t == "int" {
        return (True, float((other as PyInt).val));
    }
    if other.t == "bool" {
        if (other as PyBool).val {
            return (True, 1.0);
        }
        return (True, 0.0);
    }
    return (False, 0.0);
}

impl PyFloat.nb_binop(kind: int, other: PyObj) -> PyObj {
    (ok, b) = self._coerce(other);
    if not ok {
        return py_error("TypeError", "unsupported operand types");
    }
    a = self.val;
    if kind == NB_ADD {
        return PyFloat(t="float", val=a + b);
    }
    if kind == NB_MULTIPLY {
        return PyFloat(t="float", val=a * b);
    }
    if kind == NB_SUBTRACT {
        return PyFloat(t="float", val=a - b);
    }
    if kind == NB_TRUE_DIVIDE {
        if b == 0.0 {
            return py_error("ZeroDivisionError", "division by zero");
        }
        return PyFloat(t="float", val=a / b);
    }
    if kind == NB_REMAINDER {
        if b == 0.0 {
            return py_error("ZeroDivisionError", "division by zero");
        }
        return PyFloat(t="float", val=a % b);
    }
    if kind == NB_FLOOR_DIVIDE {
        if b == 0.0 {
            return py_error("ZeroDivisionError", "division by zero");
        }
        return PyFloat(t="float", val=a // b);
    }
    if kind == NB_POWER {
        if a == 0.0 and b < 0.0 {
            return py_error("ZeroDivisionError", "zero to a negative power");
        }
        try {
            return PyFloat(t="float", val=a ** b);
        } except OverflowError {
            return py_error("OverflowError", "(34, 'Numerical result out of range')");
        }
    }
    return py_error("TypeError", "unsupported operand types");
}

impl PyFloat.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if other.t == "int" {
        iv = (other as PyInt).val;
        if self.val == float("inf") {
            return _bool_from_cmp(1, kind);
        }
        if self.val == float("-inf") {
            return _bool_from_cmp(-1, kind);
        }
        if self.val == self.val {
            return _bool_from_cmp(-_cmp_int_vs_float(iv, self.val), kind);
        }

        if kind == 3 {
            return PyBool(t="bool", val=True);
        }
        return PyBool(t="bool", val=False);
    }
    (ok, b) = self._coerce(other);
    if not ok {
        if kind == 2 {
            return PyBool(t="bool", val=False);
        }
        if kind == 3 {
            return PyBool(t="bool", val=True);
        }
        return PY_NOT_IMPLEMENTED;
    }
    a = self.val;

    if kind == 0 {
        return PyBool(t="bool", val=a < b);
    }
    if kind == 1 {
        return PyBool(t="bool", val=a <= b);
    }
    if kind == 2 {
        return PyBool(t="bool", val=a == b);
    }
    if kind == 3 {
        return PyBool(t="bool", val=a != b);
    }
    if kind == 4 {
        return PyBool(t="bool", val=a > b);
    }
    if kind == 5 {
        return PyBool(t="bool", val=a >= b);
    }
    return PyBool(t="bool", val=False);
}

impl PyFloat.tp_bool -> bool {
    return self.val != 0.0;
}

impl PyFloat.tp_hashkey -> PyObj {
    v = self.val;
    if v != v {
        return PyStr(t="str", val="f:nan");
    }
    if v * 0.0 != 0.0 {
        return PyStr(t="str", val="f:" + str(v));
    }
    iv = int(v);
    if float(iv) == v {
        return PyStr(t="str", val="n:" + str(iv));
    }
    return PyStr(t="str", val="f:" + str(v));
}

impl PyBool.tp_bool -> bool {
    return self.val;
}

impl PyBool.to_index -> PyObj {
    if self.val {
        return PyInt(t="int", val=1);
    }
    return PyInt(t="int", val=0);
}

impl PyBool.tp_hashkey -> PyObj {
    if self.val {
        return PyStr(t="str", val="n:1");
    }
    return PyStr(t="str", val="n:0");
}

impl PyBool.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if other.t == "int" or other.t == "bool" {
        a = 0;
        if self.val {
            a = 1;
        }
        b = 0;
        if other.t == "int" {
            b = (other as PyInt).val;
        } elif (other as PyBool).val {
            b = 1;
        }
        return _bool_from_cmp(_cmp3(a, b), kind);
    }

    if other.t == "float" {
        v = 0;
        if self.val {
            v = 1;
        }
        return PyInt(t="int", val=v).tp_richcompare(kind, other);
    }
    if kind == 2 {
        return PyBool(t="bool", val=False);
    }
    if kind == 3 {
        return PyBool(t="bool", val=True);
    }
    return PY_NOT_IMPLEMENTED;
}

impl PyBool.tp_getattro(name: str) -> PyObj {
    v = 0;
    if self.val {
        v = 1;
    }
    return _number_getattro(name, v);
}

impl PyNoneType.tp_getattro(name: str) -> PyObj {
    if name == "__class__" {
        return py_exception_type("NoneType");
    }
    return py_error("AttributeError", name);
}

impl PyNoneType.tp_bool -> bool {
    return False;
}

impl PyNoneType.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if kind == 2 or kind == 3 {
        if isinstance(other, PyNoneType) {
            return PyBool(t="bool", val=kind == 2);
        }
        return PY_NOT_IMPLEMENTED;
    }
    return PY_NOT_IMPLEMENTED;
}

impl PyNoneType.tp_hashkey -> PyObj {
    return PyStr(t="str", val="n:4238894112");
}

impl PyEllipsis.tp_hashkey -> PyObj {
    return PyStr(t="str", val="ellipsis");
}

impl _cx_add(ar: float, ai: float, br: float, bi: float) -> tuple[float, float] {
    return (ar + br, ai + bi);
}

impl _cx_sub(ar: float, ai: float, br: float, bi: float) -> tuple[float, float] {
    return (ar - br, ai - bi);
}

impl _cx_mul(ar: float, ai: float, br: float, bi: float) -> tuple[float, float] {
    return (ar * br - ai * bi, ar * bi + ai * br);
}

impl _cx_is_inf(v: float) -> bool {
    if v != v {
        return False;
    }
    return v * 0.0 != 0.0;
}

impl _cx_div(ar: float, ai: float, br: float, bi: float) -> tuple[float, float] {
    abs_br = br;
    if abs_br < 0.0 {
        abs_br = -abs_br;
    }
    abs_bi = bi;
    if abs_bi < 0.0 {
        abs_bi = -abs_bi;
    }
    if abs_br >= abs_bi {
        ratio = bi / br;
        denom = br + bi * ratio;
        return ((ar + ai * ratio) / denom, (ai - ar * ratio) / denom);
    }
    ratio = br / bi;
    denom = br * ratio + bi;
    return ((ar * ratio + ai) / denom, (ai * ratio - ar) / denom);
}

impl _cx_pow_int(ar: float, ai: float, exp: int) -> tuple[int, float, float] {
    e = exp;
    neg = False;
    if e < 0 {
        neg = True;
        e = -e;
    }
    br = ar;
    bi = ai;
    if neg {
        if br == 0.0 and bi == 0.0 {
            return (2, 0.0, 0.0);
        }
        (br, bi) = _cx_div(1.0, 0.0, br, bi);
    }
    rr = 1.0;
    ri = 0.0;
    while e > 0 {
        if e % 2 == 1 {
            (rr, ri) = _cx_mul(rr, ri, br, bi);
            if _cx_is_inf(rr) or _cx_is_inf(ri) {
                return (1, 0.0, 0.0);
            }
        }
        e = e // 2;
        if e == 0 {
            break;
        }
        (br, bi) = _cx_mul(br, bi, br, bi);
        if _cx_is_inf(br) or _cx_is_inf(bi) {
            return (1, 0.0, 0.0);
        }
    }
    return (0, rr, ri);
}

impl PyComplex._coerce(other: PyObj) -> tuple[bool, float, float] {
    if isinstance(other, PyComplex) {
        c = other as PyComplex;
        return (True, c.real, c.imag);
    }
    if other.t == "float" {
        return (True, (other as PyFloat).val, 0.0);
    }
    if other.t == "int" {
        return (True, float((other as PyInt).val), 0.0);
    }
    if other.t == "bool" {
        if (other as PyBool).val {
            return (True, 1.0, 0.0);
        }
        return (True, 0.0, 0.0);
    }
    return (False, 0.0, 0.0);
}

impl PyComplex.nb_binop(kind: int, other: PyObj) -> PyObj {
    (ok, br, bi) = self._coerce(other);
    if not ok {
        return py_error("TypeError", "unsupported operand types");
    }
    ar = self.real;
    ai = self.imag;
    if kind == NB_ADD {
        (r, i) = _cx_add(ar, ai, br, bi);
        return PyComplex(t="complex", real=r, imag=i);
    }
    if kind == NB_SUBTRACT {
        (r, i) = _cx_sub(ar, ai, br, bi);
        return PyComplex(t="complex", real=r, imag=i);
    }
    if kind == NB_MULTIPLY {
        (r, i) = _cx_mul(ar, ai, br, bi);
        return PyComplex(t="complex", real=r, imag=i);
    }
    if kind == NB_TRUE_DIVIDE {
        if br == 0.0 and bi == 0.0 {
            return py_error("ZeroDivisionError", "division by zero");
        }
        (r, i) = _cx_div(ar, ai, br, bi);
        return PyComplex(t="complex", real=r, imag=i);
    }
    if kind == NB_POWER {
        if bi == 0.0 and -100.0 < br and br < 100.0 {
            iv = int(br);
            if float(iv) == br {
                (err, r, i) = _cx_pow_int(ar, ai, iv);
                if err == 1 {
                    return py_error("OverflowError", "complex exponentiation");
                }
                if err == 2 {
                    return py_error(
                        "ZeroDivisionError", "zero to a negative or complex power"
                    );
                }
                return PyComplex(t="complex", real=r, imag=i);
            }
        }
        return py_error("TypeError", "unsupported operand types");
    }

    return py_error("TypeError", "unsupported operand types");
}

impl PyComplex._reflected_binop(kind: int, other: PyObj) -> PyObj {
    (ok, lr, li) = self._coerce(other);
    if not ok {
        return PY_NOT_IMPLEMENTED;
    }
    ar = self.real;
    ai = self.imag;
    if kind == NB_ADD {
        (r, i) = _cx_add(lr, li, ar, ai);
        return PyComplex(t="complex", real=r, imag=i);
    }
    if kind == NB_SUBTRACT {
        (r, i) = _cx_sub(lr, li, ar, ai);
        return PyComplex(t="complex", real=r, imag=i);
    }
    if kind == NB_MULTIPLY {
        (r, i) = _cx_mul(lr, li, ar, ai);
        return PyComplex(t="complex", real=r, imag=i);
    }
    if kind == NB_TRUE_DIVIDE {
        if ar == 0.0 and ai == 0.0 {
            return py_error("ZeroDivisionError", "division by zero");
        }
        (r, i) = _cx_div(lr, li, ar, ai);
        return PyComplex(t="complex", real=r, imag=i);
    }
    if kind == NB_POWER {
        if ai == 0.0 and -100.0 < ar and ar < 100.0 {
            iv = int(ar);
            if float(iv) == ar {
                (err, r, i) = _cx_pow_int(lr, li, iv);
                if err == 1 {
                    return py_error("OverflowError", "complex exponentiation");
                }
                if err == 2 {
                    return py_error(
                        "ZeroDivisionError", "zero to a negative or complex power"
                    );
                }
                return PyComplex(t="complex", real=r, imag=i);
            }
        }
    }
    return PY_NOT_IMPLEMENTED;
}

impl PyComplex.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if kind != Py_EQ and kind != Py_NE {
        return PY_NOT_IMPLEMENTED;
    }
    (ok, br, bi) = self._coerce(other);
    if ok {
        eqv = self.real == br and self.imag == bi;
        if kind == Py_EQ {
            return PyBool(t="bool", val=eqv);
        }
        return PyBool(t="bool", val=not eqv);
    }

    if kind == Py_EQ {
        return PyBool(t="bool", val=False);
    }
    return PyBool(t="bool", val=True);
}

impl PyComplex.tp_bool -> bool {
    return self.real != 0.0 or self.imag != 0.0;
}

impl PyComplex.tp_hashkey -> PyObj {
    if self.imag == 0.0 {
        return PyFloat(t="float", val=self.real).tp_hashkey();
    }
    r = self.real;
    if r == 0.0 {
        r = 0.0;
    }
    return PyStr(t="str", val="z:" + str(r) + "," + str(self.imag));
}

impl PyComplex.tp_getattro(name: str) -> PyObj {
    if name == "real" {
        return PyFloat(t="float", val=self.real);
    }
    if name == "imag" {
        return PyFloat(t="float", val=self.imag);
    }
    if name == "conjugate" {
        return PyComplexMethod(t="complex_method", target=self, name=name);
    }
    return py_error(
        "AttributeError", "'complex' object has no attribute '" + name + "'"
    );
}

impl PyComplexMethod.tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", self.name + "() takes no keyword arguments");
    }
    if len(args) != 0 {
        return py_error(
            "TypeError",
            self.name + "() takes no arguments (" + str(len(args)) + " given)",
        );
    }
    return PyComplex(t="complex", real=self.target.real, imag=-self.target.imag);
}

impl PySliceIndices.tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", "slice.indices() takes no keyword arguments");
    }
    if len(args) != 1 {
        return py_error(
            "TypeError",
            "slice.indices() takes exactly one argument (" + str(len(args)) + " given)",
        );
    }
    err = _zero_step_error(self.sl);
    if is_error(err) {
        return err;
    }
    length_obj = args[0].to_index();
    if is_error(length_obj) {
        return py_error(
            "TypeError",
            "'" + args[0].t + "' object cannot be interpreted as an integer",
        );
    }
    b = slice_indices(self.sl, (length_obj as PyInt).val);
    out: list[PyObj] = [];
    for v in b {
        out.append(PyInt(t="int", val=v));
    }
    return PyTuple(t="tuple", items=out);
}

impl PySlice.tp_getattro(name2: str) -> PyObj {
    if name2 == "start" {
        return self.start;
    }
    if name2 == "stop" {
        return self.stop;
    }
    if name2 == "step" {
        return self.step;
    }
    if name2 == "indices" {
        return PySliceIndices(t="slice_indices", sl=self);
    }
    return py_error(
        "AttributeError", "'slice' object has no attribute '" + name2 + "'"
    );
}

impl PySlice.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if kind != Py_EQ and kind != Py_NE {
        return PY_NOT_IMPLEMENTED;
    }
    if not isinstance(other, PySlice) {
        return PY_NOT_IMPLEMENTED;
    }
    os = other as PySlice;
    fields: list[PyObj] = [self.start, self.stop, self.step];
    other_fields: list[PyObj] = [os.start, os.stop, os.step];
    for i in range(len(fields)) {
        eq = py_rich_compare(fields[i], other_fields[i], Py_EQ);
        if is_error(eq) {
            return eq;
        }
        if _richcompare_truth(eq) != 1 {
            return PyBool(t="bool", val=kind == Py_NE);
        }
    }
    return PyBool(t="bool", val=kind == Py_EQ);
}

impl PyTuple.nb_binop(kind: int, other: PyObj) -> PyObj {
    if kind == NB_ADD and other.t == "tuple" {
        return PyTuple(
            t="tuple", items=concat_items(self.items, (other as PyTuple).items)
        );
    }
    if kind == NB_MULTIPLY {
        idx = other.to_index();
        if is_error(idx) {
            return py_error(
                "TypeError",
                "can't multiply sequence by non-int of type '" + other.t + "'",
            );
        }
        n = (idx as PyInt).val;
        repeated: list[PyObj] = [];
        while n > 0 {
            repeated.extend(self.items);
            n = n - 1;
        }
        return PyTuple(t="tuple", items=repeated);
    }
    return py_error("TypeError", "unsupported operand types");
}

impl PyTuple.mp_subscript(index: PyObj) -> PyObj {
    if isinstance(index, PySlice) {
        err = _zero_step_error(index as PySlice);
        if is_error(err) {
            return err;
        }
        return PyTuple(t="tuple", items=_slice_objs(self.items, index as PySlice));
    }
    pos = _seq_index(
        index,
        len(self.items),
        "tuple indices must be integers or slices",
        "tuple index out of range",
    );
    if is_error(pos) {
        return pos;
    }
    return self.items[(pos as PyInt).val];
}

impl PyTuple.tp_iter -> PyObj {
    return PyIter(t="iter", items=self.items, index=0);
}

impl PyTuple.tp_bool -> bool {
    return len(self.items) != 0;
}

impl PyTuple.tp_hashkey -> PyObj {
    key = "t:";
    for item in self.items {
        sub = item.tp_hashkey();
        if is_error(sub) {
            return sub;
        }
        subk = hashkey_str(sub);
        key = key + str(len(subk)) + ":" + subk;
    }
    return PyStr(t="str", val=key);
}

impl PyTuple.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if not isinstance(other, PyTuple) {
        return PY_NOT_IMPLEMENTED;
    }
    w = other as PyTuple;
    vlen = len(self.items);
    wlen = len(w.items);
    i = 0;
    while i < vlen and i < wlen {
        k = py_rich_compare_bool(self.items[i], w.items[i], Py_EQ);
        if k < 0 {
            return py_rich_compare(self.items[i], w.items[i], Py_EQ);
        }
        if k == 0 {
            break;
        }
        i = i + 1;
    }
    if i >= vlen or i >= wlen {
        return _bool_from_cmp(_cmp3(vlen, wlen), kind);
    }
    if kind == Py_EQ {
        return PyBool(t="bool", val=False);
    }
    if kind == Py_NE {
        return PyBool(t="bool", val=True);
    }
    return py_rich_compare(self.items[i], w.items[i], kind);
}

impl PyStructTime.tp_getattro(name: str) -> PyObj {
    fields: list[str] = [
        "tm_year",
        "tm_mon",
        "tm_mday",
        "tm_hour",
        "tm_min",
        "tm_sec",
        "tm_wday",
        "tm_yday",
        "tm_isdst",

    ];
    i = 0;
    while i < len(fields) {
        if name == fields[i] {
            return self.items[i];
        }
        i = i + 1;
    }
    if name == "tm_gmtoff" or name == "tm_zone" {
        idx = 9;
        if name == "tm_zone" {
            idx = 10;
        }
        if len(self.items) > idx {
            return self.items[idx];
        }

        return py_error(
            "AttributeError",
            "'time.struct_time' object has no attribute '" + name + "'",
        );
    }
    if name == "n_sequence_fields" {
        return PyInt(t="int", val=9);
    }
    if name == "n_fields" {
        return PyInt(t="int", val=len(self.items));
    }
    if name == "n_unnamed_fields" {
        return PyInt(t="int", val=0);
    }
    return py_error(
        "AttributeError", "'time.struct_time' object has no attribute '" + name + "'",
    );
}

impl PyStructTime.tp_repr -> PyObj {
    names: list[str] = [
        "tm_year",
        "tm_mon",
        "tm_mday",
        "tm_hour",
        "tm_min",
        "tm_sec",
        "tm_wday",
        "tm_yday",
        "tm_isdst",
        "tm_gmtoff",
        "tm_zone",

    ];
    out = "time.struct_time(";
    i2 = 0;
    while i2 < len(self.items) and i2 < len(names) {
        if i2 > 0 {
            out = out + ", ";
        }
        out = out + names[i2] + "=" + _struct_time_field_repr(self.items[i2]);
        i2 = i2 + 1;
    }
    return PyStr(t="str", val=out + ")");
}

impl _struct_time_field_repr(v: PyObj) -> str {
    if isinstance(v, PyStr) {
        return "'" + (v as PyStr).val + "'";
    }
    if isinstance(v, PyBool) {
        if (v as PyBool).val {
            return "True";
        }
        return "False";
    }
    if isinstance(v, PyNoneType) {
        return "None";
    }
    if isinstance(v, PyFloat) {
        return str((v as PyFloat).val);
    }
    if isinstance(v, PyInt) {
        return str((v as PyInt).val);
    }
    return "<unrepresentable>";
}

impl PyList.nb_binop(kind: int, other: PyObj) -> PyObj {
    if kind == NB_ADD and other.t == "list" {
        return PyList(
            t="list", items=concat_items(self.items, (other as PyList).items)
        );
    }
    if kind == NB_MULTIPLY {
        idx = other.to_index();
        if is_error(idx) {
            return py_error(
                "TypeError",
                "can't multiply sequence by non-int of type '" + other.t + "'",
            );
        }
        n = (idx as PyInt).val;
        repeated: list[PyObj] = [];
        while n > 0 {
            repeated.extend(self.items);
            n = n - 1;
        }
        return PyList(t="list", items=repeated);
    }
    return py_error("TypeError", "unsupported operand types");
}

impl PyList.mp_subscript(index: PyObj) -> PyObj {
    if isinstance(index, PySlice) {
        err = _zero_step_error(index as PySlice);
        if is_error(err) {
            return err;
        }
        return PyList(t="list", items=_slice_objs(self.items, index as PySlice));
    }
    pos = _seq_index(
        index,
        len(self.items),
        "list indices must be integers or slices",
        "list index out of range",
    );
    if is_error(pos) {
        return pos;
    }
    return self.items[(pos as PyInt).val];
}

impl PyList.mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
    if isinstance(index, PySlice) {
        err = _zero_step_error(index as PySlice);
        if is_error(err) {
            return err;
        }
        if not isinstance(value, PyList) {
            return py_error("TypeError", "can only assign an iterable");
        }
        vals = (value as PyList).items;
        b = slice_indices(index as PySlice, len(self.items));
        si = b[0];
        stop = b[1];
        step = b[2];
        if step == 1 {
            kept: list[PyObj] = [];
            k = 0;
            while k < si {
                kept.append(self.items[k]);
                k = k + 1;
            }
            kept.extend(vals);
            k = stop;
            while k < len(self.items) {
                kept.append(self.items[k]);
                k = k + 1;
            }
            self.items = kept;
            return py_none();
        }
        count = 0;
        probe = si;
        if step > 0 {
            while probe < stop {
                count = count + 1;
                probe = probe + step;
            }
        } else {
            while probe > stop {
                count = count + 1;
                probe = probe + step;
            }
        }
        if len(vals) != count {
            return py_error(
                "ValueError",
                "attempt to assign sequence of size "
                    + str(len(vals))
                    + " to extended slice of size "
                    + str(count),
            );
        }
        new_items: list[PyObj] = [];
        new_items.extend(self.items);
        pos = si;
        vi = 0;
        if step > 0 {
            while pos < stop {
                new_items[pos] = vals[vi];
                pos = pos + step;
                vi = vi + 1;
            }
        } else {
            while pos > stop {
                new_items[pos] = vals[vi];
                pos = pos + step;
                vi = vi + 1;
            }
        }
        self.items = new_items;
        return py_none();
    }
    npos = _seq_index(
        index,
        len(self.items),
        "list indices must be integers",
        "list assignment index out of range",
    );
    if is_error(npos) {
        return npos;
    }
    self.items[(npos as PyInt).val] = value;
    return py_none();
}

impl PyList.mp_del_subscript(index: PyObj) -> PyObj {
    if isinstance(index, PySlice) {
        err = _zero_step_error(index as PySlice);
        if is_error(err) {
            return err;
        }
        b = slice_indices(index as PySlice, len(self.items));
        si = b[0];
        stop = b[1];
        step = b[2];
        drop: dict[int, bool] = {};
        if step > 0 {
            while si < stop {
                drop[si] = True;
                si = si + step;
            }
        } else {
            while si > stop {
                drop[si] = True;
                si = si + step;
            }
        }
        kept: list[PyObj] = [];
        k = 0;
        while k < len(self.items) {
            if not (k in drop) {
                kept.append(self.items[k]);
            }
            k = k + 1;
        }
        self.items = kept;
        return py_none();
    }
    pos = _seq_index(
        index,
        len(self.items),
        "list indices must be integers",
        "list assignment index out of range",
    );
    if is_error(pos) {
        return pos;
    }
    del self.items[(pos as PyInt).val];
    return py_none();
}

impl PyList.tp_iter -> PyObj {
    return PyIter(t="iter", items=self.items, index=0);
}

impl PyList.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if not isinstance(other, PyList) {
        return PY_NOT_IMPLEMENTED;
    }
    w = other as PyList;
    if len(self.items) != len(w.items) and (kind == Py_EQ or kind == Py_NE) {
        return PyBool(t="bool", val=kind == Py_NE);
    }
    i = 0;
    while i < len(self.items) and i < len(w.items) {
        vitem = self.items[i];
        witem = w.items[i];
        if vitem is witem {
            i = i + 1;
            continue;
        }
        keq = py_rich_compare(vitem, witem, Py_EQ);
        if is_error(keq) {
            return keq;
        }
        if _richcompare_truth(keq) != 1 {
            break;
        }
        i = i + 1;
    }
    vlen = len(self.items);
    wlen = len(w.items);
    if i >= vlen or i >= wlen {
        return _bool_from_cmp(_cmp3(vlen, wlen), kind);
    }
    if kind == Py_EQ {
        return PyBool(t="bool", val=False);
    }
    if kind == Py_NE {
        return PyBool(t="bool", val=True);
    }
    return py_rich_compare(self.items[i], w.items[i], kind);
}

impl PyList.tp_bool -> bool {
    return len(self.items) != 0;
}

impl PyCode.tp_hashkey -> PyObj {
    result = (
        "code:"
        + self.name
        + ":"
        + self.qualname
        + ":"
        + str(self.firstlineno)
        + ":"
        + str(len(self.co_code))
    );
    ci = 0;
    while ci < len(self.co_code) {
        result = result + ":" + str(self.co_code[ci]);
        ci = ci + 1;
    }
    return PyStr(t="str", val=result);
}

impl PyCode.tp_getattro(name: str) -> PyObj {
    if name == "co_argcount" {
        return PyInt(t="int", val=self.argcount);
    }
    if name == "co_posonlyargcount" {
        return PyInt(t="int", val=self.posonlyargcount);
    }
    if name == "co_kwonlyargcount" {
        return PyInt(t="int", val=self.kwonlyargcount);
    }
    if name == "co_stacksize" {
        return PyInt(t="int", val=self.stacksize);
    }
    if name == "co_flags" {
        return PyInt(t="int", val=self.flags);
    }
    if name == "co_name" {
        return PyStr(t="str", val=self.name);
    }
    if name == "co_qualname" {
        return PyStr(t="str", val=self.qualname);
    }
    if name == "co_filename" {
        return PyStr(t="str", val=self.filename);
    }
    if name == "co_firstlineno" {
        return PyInt(t="int", val=self.firstlineno);
    }
    if name == "co_names"
        or name == "co_varnames"
        or name == "co_cellvars"
        or name == "co_freevars" {
        items: list[PyObj] = [];
        src_names: list[str] = [];
        if name == "co_names" {
            src_names = self.names;
        } elif name == "co_varnames" {
            src_names = self.varnames;
        } elif name == "co_cellvars" {
            src_names = self.cellvars;
        } else {
            src_names = self.freevars;
        }
        for n in src_names {
            items.append(PyStr(t="str", val=n));
        }
        return PyTuple(t="tuple", items=items);
    }
    if name == "co_consts" {
        return PyTuple(t="tuple", items=self.consts);
    }
    if name == "co_code" {
        return PyBytes(t="bytes", val=self.co_code);
    }
    return py_error("AttributeError", "'code' object has no attribute '" + name + "'");
}

impl PyTypeAlias.tp_getattro(name: str) -> PyObj {
    if name == "__name__" {
        return PyStr(t="str", val=self.name);
    }
    if name == "__type_params__" {
        if self.type_params.t == "none" {
            return PyTuple(t="tuple", items=[]);
        }
        return self.type_params;
    }
    return py_error("AttributeError", name);
}

impl PyTypeVar.tp_getattro(name: str) -> PyObj {
    if name == "__name__" {
        return PyStr(t="str", val=self.name);
    }
    if name == "__module__" {
        return PyStr(t="str", val="typing");
    }
    if name == "__infer_variance__" {
        return PyBool(t="bool", val=self.infer_variance);
    }
    if name == "__covariant__" {
        return PyBool(t="bool", val=self.covariant);
    }
    if name == "__contravariant__" {
        return PyBool(t="bool", val=self.contravariant);
    }

    if name == "evaluate_bound" {
        return self.evaluate_bound;
    }
    if name == "evaluate_constraints" {
        return self.evaluate_constraints;
    }
    if name == "evaluate_default" {
        return self.evaluate_default;
    }

    return py_error(
        "AttributeError", "'typing.TypeVar' object has no attribute '" + name + "'"
    );
}

impl _dict_ensure_order(d: PyDict) -> PyObj {
    if len(d.order) > 0 {
        return py_none();
    }
    for sk in d.items {
        d.order.append(sk);
    }
    return py_none();
}

impl _set_ensure_order(s: PySet) -> PyObj {
    if len(s.order) > 0 {
        return py_none();
    }
    for sk in s.items {
        s.order.append(sk);
    }
    return py_none();
}

impl _dict_new_slot(d: PyDict, hk: str) -> str {
    if not (hk in d.items) {
        return hk;
    }
    n = 0;
    while True {
        sk = hk + _DICT_SLOT_COLL + str(n);
        if not (sk in d.items) {
            return sk;
        }
        n = n + 1;
    }
}

impl _set_new_slot(s: PySet, hk: str) -> str {
    if not (hk in s.items) {
        return hk;
    }
    n = 0;
    while True {
        sk = hk + _DICT_SLOT_COLL + str(n);
        if not (sk in s.items) {
            return sk;
        }
        n = n + 1;
    }
}

impl _dict_remove_slot(d: PyDict, sk: str) -> PyObj {
    del d.items[sk];
    kept: list[str] = [];
    for x in d.order {
        if x != sk {
            kept.append(x);
        }
    }

    d.order.clear();
    d.order.extend(kept);
    return py_none();
}

impl _set_remove_slot(s: PySet, sk: str) -> PyObj {
    del s.items[sk];
    kept: list[str] = [];
    for x in s.order {
        if x != sk {
            kept.append(x);
        }
    }

    s.order.clear();
    s.order.extend(kept);
    return py_none();
}

impl _dict_find_entry(d: PyDict, key: PyObj) -> PyObj {
    _dict_ensure_order(d);
    hkr = key.tp_hashkey();
    if is_error(hkr) {
        return hkr;
    }
    hk = hashkey_str(hkr);
    for sk in d.order {
        ent = d.items[sk];
        stored = ent.key;
        if key is stored {
            return PyStr(t="str", val=sk);
        }
        skr = stored.tp_hashkey();
        if is_error(skr) {
            continue;
        }
        if hashkey_str(skr) != hk {
            continue;
        }
        eq = py_rich_compare(key, stored, Py_EQ);
        if is_error(eq) {
            return eq;
        }
        if _richcompare_truth(eq) == 1 {
            return PyStr(t="str", val=sk);
        }
    }
    return py_none();
}

impl _set_push_member(
    items: dict[str, PyObj], order: list[str], member: PyObj
) -> PyObj {
    probe = PySet(t="set", items=items, order=order, frozen=False);
    if probe.set_contains(member) {
        return py_none();
    }
    hkr = member.tp_hashkey();
    if is_error(hkr) {
        return hkr;
    }
    sk = _set_new_slot(probe, hashkey_str(hkr));
    items[sk] = member;
    order.append(sk);
    return py_none();
}

impl _set_find_entry(s: PySet, member: PyObj) -> PyObj {
    _set_ensure_order(s);
    hkr = member.tp_hashkey();
    if is_error(hkr) {
        return hkr;
    }
    hk = hashkey_str(hkr);
    for sk in s.order {
        stored = s.items[sk];
        if member is stored {
            return PyStr(t="str", val=sk);
        }
        skr = stored.tp_hashkey();
        if is_error(skr) {
            continue;
        }
        if hashkey_str(skr) != hk {
            continue;
        }
        eq = py_rich_compare(member, stored, Py_EQ);
        if is_error(eq) {
            return eq;
        }
        if _richcompare_truth(eq) == 1 {
            return PyStr(t="str", val=sk);
        }
    }
    return py_none();
}

impl _set_remove_member(
    items: dict[str, PyObj], order: list[str], member: PyObj
) -> PyObj {
    probe = PySet(t="set", items=items, order=order, frozen=False);
    found = _set_find_entry(probe, member);
    if is_error(found) {
        return found;
    }
    if found.t == "none" {
        return py_none();
    }
    return _set_remove_slot(probe, expect_str(found));
}

impl PyDictIter.dictiter_stale -> bool {
    return self.d.version != self.snap_version;
}

impl PyDict.tp_iter -> PyObj {
    return self.dict_iter("keys");
}

impl PyDict.dict_iter(mode: str) -> PyDictIter {
    _dict_ensure_order(self);
    keys: list[str] = [];
    for sk in self.order {
        keys.append(sk);
    }
    return PyDictIter(
        t="dictiter", d=self, keys=keys, index=0, snap_version=self.version, mode=mode
    );
}

impl PyDict.mp_subscript(index: PyObj) -> PyObj {
    found = _dict_find_entry(self, index);
    if is_error(found) {
        return found;
    }
    if found.t == "none" {
        return py_error("KeyError", dict_key_repr(index));
    }
    sk = expect_str(found);
    return self.items[sk].value;
}

impl PyDict.mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
    hkr = index.tp_hashkey();
    if is_error(hkr) {
        return _unhashable_error("a dict key", index);
    }
    hk = hashkey_str(hkr);
    found = _dict_find_entry(self, index);
    if is_error(found) {
        return found;
    }
    if found.t != "none" {
        sk = expect_str(found);

        self.items[sk] = DictEntry(key=self.items[sk].key, value=value);
    } else {
        sk = _dict_new_slot(self, hk);
        self.items[sk] = DictEntry(key=index, value=value);
        self.order.append(sk);
        self.version = self.version + 1;
    }
    return py_none();
}

impl PyDict.mp_del_subscript(index: PyObj) -> PyObj {
    found = _dict_find_entry(self, index);
    if is_error(found) {
        return found;
    }
    if found.t == "none" {
        return py_error("KeyError", dict_key_repr(index));
    }
    sk = expect_str(found);
    _dict_remove_slot(self, sk);
    self.version = self.version + 1;
    return py_none();
}

impl PyDict.dict_set(keyobj: PyObj, value: PyObj) -> PyObj {
    return self.mp_ass_subscript(keyobj, value);
}

impl PyDict.dict_equal(b: PyDict) -> PyObj {
    _dict_ensure_order(self);
    _dict_ensure_order(b);
    if len(self.order) != len(b.order) {
        return PyBool(t="bool", val=False);
    }
    for sk in self.order {
        ent = self.items[sk];
        ak = ent.key;
        av = ent.value;
        bfound = _dict_find_entry(b, ak);
        if is_error(bfound) {
            return bfound;
        }
        if bfound.t == "none" {
            return PyBool(t="bool", val=False);
        }
        bsk = expect_str(bfound);
        bv = b.items[bsk].value;
        if av is not bv {
            veq = py_rich_compare(av, bv, Py_EQ);
            if is_error(veq) {
                return veq;
            }
            if _richcompare_truth(veq) != 1 {
                return PyBool(t="bool", val=False);
            }
        }
    }
    return PyBool(t="bool", val=True);
}

impl PyDict.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if (kind != Py_EQ and kind != Py_NE) or not isinstance(other, PyDict) {
        return PY_NOT_IMPLEMENTED;
    }
    eq = self.dict_equal(other as PyDict);
    if is_error(eq) {
        return eq;
    }
    if kind == Py_NE {
        return PyBool(t="bool", val=_richcompare_truth(eq) != 1);
    }
    return eq;
}

impl PyDict.dict_contains(keyobj: PyObj) -> bool {
    found = _dict_find_entry(self, keyobj);
    if is_error(found) {
        return False;
    }
    return found.t != "none";
}

impl PyDict.dict_keys -> list[PyObj] {
    _dict_ensure_order(self);
    out: list[PyObj] = [];
    for sk in self.order {
        out.append(self.items[sk].key);
    }
    return out;
}

impl PyDict.dict_values -> list[PyObj] {
    _dict_ensure_order(self);
    out: list[PyObj] = [];
    for sk in self.order {
        out.append(self.items[sk].value);
    }
    return out;
}

impl PyDict.dict_str_map -> dict[str, PyObj] {
    _dict_ensure_order(self);
    out: dict[str, PyObj] = {};
    for sk in self.order {
        `entry = self.items[sk];
        if `entry.key.t == "str" {
            out[expect_str(`entry.key)] = `entry.value;
        }
    }
    return out;
}

impl PyDict.tp_getattro(name: str) -> PyObj {
    hk = "s:" + name;
    if hk in self.items {
        return self.items[hk].value;
    }
    return py_error("AttributeError", name);
}

impl PyDict.tp_bool -> bool {
    return len(self.items) != 0;
}

impl PySet.set_contains(member: PyObj) -> bool {
    found = _set_contains_elem(self, member);
    if is_error(found) {
        return False;
    }
    if isinstance(found, PyBool) {
        return (found as PyBool).val;
    }
    return True;
}

impl PySet.set_lookup(member: PyObj) -> PyObj {
    return _set_contains_elem(self, member);
}

impl PySet.set_add(member: PyObj) -> PyObj {
    hkr = member.tp_hashkey();
    if is_error(hkr) {
        return _unhashable_error("a set element", member);
    }
    hk = hashkey_str(hkr);
    found = _set_find_entry(self, member);
    if is_error(found) {
        return found;
    }
    if found.t != "none" {
        return py_none();
    }

    sk = _set_new_slot(self, hk);
    self.items[sk] = member;
    self.order.append(sk);
    return py_none();
}

impl PySet.set_pop -> PyObj {
    _set_ensure_order(self);
    if len(self.order) == 0 {
        return py_error("KeyError", "pop from an empty set");
    }
    sk = self.order[0];
    member = self.items[sk];
    _set_remove_slot(self, sk);
    return member;
}

impl PySet.set_discard(member: PyObj) -> PyObj {
    found = _set_find_entry(self, member);
    if is_error(found) {
        return py_error("TypeError", "unhashable type");
    }
    if found.t != "none" {
        sk = expect_str(found);
        _set_remove_slot(self, sk);
    }
    return py_none();
}

impl PySet.set_clear -> PyObj {
    self.items = {};
    self.order = [];
    return py_none();
}

impl PySet.set_copy -> PyObj {
    _set_ensure_order(self);
    copy_items: dict[str, PyObj] = {};
    copy_order: list[str] = [];
    for sk in self.order {
        copy_items[sk] = self.items[sk];
        copy_order.append(sk);
    }
    return PySet(t=self.t, items=copy_items, order=copy_order, frozen=self.frozen);
}

impl PySet.set_members -> list[PyObj] {
    _set_ensure_order(self);
    out: list[PyObj] = [];
    for sk in self.order {
        out.append(self.items[sk]);
    }
    return out;
}

impl PySet.tp_iter -> PyObj {
    return PyIter(t="iter", items=self.set_members(), index=0);
}

impl PySet.tp_bool -> bool {
    return len(self.items) != 0;
}

impl PySet.tp_hashkey -> PyObj {
    if not self.frozen {
        return py_error("TypeError", "unhashable type");
    }
    _set_ensure_order(self);
    keys: list[str] = [];
    for sk in self.order {
        hkr = self.items[sk].tp_hashkey();
        if is_error(hkr) {
            return hkr;
        }
        keys.append(hashkey_str(hkr));
    }
    i = 1;
    while i < len(keys) {
        cur = keys[i];
        j = i - 1;
        while j >= 0 and keys[j] > cur {
            keys[j + 1] = keys[j];
            j = j - 1;
        }
        keys[j + 1] = cur;
        i = i + 1;
    }
    result = "fs:" + str(len(keys));
    for k in keys {
        result = result + ":" + str(len(k)) + ":" + k;
    }
    return PyStr(t="str", val=result);
}

impl PySet.nb_binop(kind: int, other: PyObj) -> PyObj {
    if not isinstance(other, PySet) {
        return py_error("TypeError", "unsupported operand types");
    }
    o = other as PySet;
    _set_ensure_order(self);
    _set_ensure_order(o);
    result_items: dict[str, PyObj] = {};
    result_order: list[str] = [];
    if kind == NB_OR {
        for sk in self.order {
            err = _set_push_member(result_items, result_order, self.items[sk]);
            if is_error(err) {
                return err;
            }
        }
        for sk in o.order {
            err = _set_push_member(result_items, result_order, o.items[sk]);
            if is_error(err) {
                return err;
            }
        }
    } elif kind == NB_AND {
        for sk in self.order {
            m = self.items[sk];
            if o.set_contains(m) {
                err = _set_push_member(result_items, result_order, m);
                if is_error(err) {
                    return err;
                }
            }
        }
    } elif kind == NB_SUBTRACT {
        for sk in self.order {
            m = self.items[sk];
            if not o.set_contains(m) {
                err = _set_push_member(result_items, result_order, m);
                if is_error(err) {
                    return err;
                }
            }
        }
    } elif kind == NB_XOR {
        for sk in self.order {
            err = _set_push_member(result_items, result_order, self.items[sk]);
            if is_error(err) {
                return err;
            }
        }
        for sk in o.order {
            m = o.items[sk];
            probe = PySet(
                t=self.t, items=result_items, order=result_order, frozen=False
            );
            if probe.set_contains(m) {
                err = _set_remove_member(result_items, result_order, m);
                if is_error(err) {
                    return err;
                }
            } else {
                err = _set_push_member(result_items, result_order, m);
                if is_error(err) {
                    return err;
                }
            }
        }
    } else {
        return py_error("TypeError", "unsupported operand types");
    }
    return PySet(t=self.t, items=result_items, order=result_order, frozen=self.frozen);
}

impl PySet.tp_richcompare(kind: int, other: PyObj) -> PyObj {
    if not isinstance(other, PySet) {
        if kind == 2 {
            return PyBool(t="bool", val=False);
        }
        if kind == 3 {
            return PyBool(t="bool", val=True);
        }
        return PY_NOT_IMPLEMENTED;
    }
    return _pyset_richcompare_na(kind, self, other as PySet);
}

impl _richcompare_truth(res: PyObj) -> int {
    if is_error(res) {
        return -1;
    }
    if isinstance(res, PyBool) {
        if (res as PyBool).val {
            return 1;
        }
        return 0;
    }
    if res.t == "none" {
        return 0;
    }
    if res.t == "int" {
        if (res as PyInt).val != 0 {
            return 1;
        }
        return 0;
    }
    return 1;
}

impl py_rich_compare(v: PyObj, w: PyObj, op: int) -> PyObj {
    res = v.tp_richcompare(op, w);
    if is_error(res) {
        return res;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return res;
    }
    swapped = _PY_SWAPPED_OP[op];
    res = w.tp_richcompare(swapped, v);
    if is_error(res) {
        return res;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return res;
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=v is w);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=v is not w);
    }
    return py_ordering_type_error(op, v, w, _base_type_name);
}

impl _base_type_name(v: PyObj) -> str {
    if v.t == "none" {
        return "NoneType";
    }
    return v.t;
}

impl py_ordering_type_error(
    op_kind: int, v: PyObj, w: PyObj, type_name_fn: Callable[[PyObj], str]
) -> PyObj {
    ops = ["<", "<=", "", "", ">", ">="];
    if op_kind < 0 or op_kind >= len(ops) or ops[op_kind] == "" {
        return py_error("TypeError", "invalid rich comparison opcode");
    }
    return py_error(
        "TypeError",
        "'"
            + ops[op_kind]
            + "' not supported between instances of '"
            + type_name_fn(v)
            + "' and '"
            + type_name_fn(w)
            + "'"
    );
}

impl py_rich_compare_bool(v: PyObj, w: PyObj, op: int) -> int {
    if v is w {
        if op == Py_EQ {
            return 1;
        }
        if op == Py_NE {
            return 0;
        }
    }
    res = py_rich_compare(v, w, op);
    return _richcompare_truth(res);
}

impl _cmp3(a: int, b: int) -> int {
    if a < b {
        return -1;
    }
    if a > b {
        return 1;
    }
    return 0;
}

impl _cmp3_str(a: str, b: str) -> int {
    if a < b {
        return -1;
    }
    if a > b {
        return 1;
    }
    return 0;
}

impl _bool_from_cmp(cmp: int, op: int) -> PyObj {
    if op == Py_LT {
        return PyBool(t="bool", val=cmp < 0);
    }
    if op == Py_LE {
        return PyBool(t="bool", val=cmp <= 0);
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=cmp == 0);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=cmp != 0);
    }
    if op == Py_GT {
        return PyBool(t="bool", val=cmp > 0);
    }
    if op == Py_GE {
        return PyBool(t="bool", val=cmp >= 0);
    }
    return PyBool(t="bool", val=False);
}

impl _unhashable_error(what: str, v: PyObj) -> PyObj {
    name = v.tp_type_name();
    return py_error(
        "TypeError",
        "cannot use '" + name + "' as " + what + " (unhashable type: '" + name + "')"
    );
}

impl _set_contains_elem(so: PySet, key: PyObj) -> PyObj {
    found = _set_find_entry(so, key);
    if is_error(found) {
        return found;
    }
    if found.t == "none" {
        return PyBool(t="bool", val=False);
    }
    return PyBool(t="bool", val=True);
}

impl _pyset_richcompare_na(op: int, v: PySet, w: PySet) -> PyObj {
    _set_ensure_order(v);
    _set_ensure_order(w);
    v_sub = True;
    for sk in v.order {
        elem = v.items[sk];
        found = _set_contains_elem(w, elem);
        if is_error(found) {
            return found;
        }
        if not (found as PyBool).val {
            v_sub = False;
        }
    }
    w_sub = True;
    for sk in w.order {
        elem = w.items[sk];
        found = _set_contains_elem(v, elem);
        if is_error(found) {
            return found;
        }
        if not (found as PyBool).val {
            w_sub = False;
        }
    }
    eq = v_sub and w_sub;

    cmp = 0;
    if not eq {
        if v_sub {
            cmp = -1;
        } else {
            cmp = 1;
        }
    }
    return _bool_from_cmp(cmp, op);
}

impl PyTraceback.tp_getattro(name2: str) -> PyObj {
    if name2 == "__class__" {
        return py_exception_type("traceback");
    }
    if name2 == "tb_next" {
        if self.tb_next is not None {
            return self.tb_next as PyObj;
        }
        return py_none();
    }
    if name2 == "tb_lineno" or name2 == "tb_lasti" or name2 == "tb_frame" {
        if name2 == "tb_lineno" {
            return PyInt(t="int", val=self.tb_lineno);
        }
        if name2 == "tb_lasti" {
            return PyInt(t="int", val=self.tb_lasti);
        }
        return PyTracebackFrame(
            t="frame", frame_code=self.code, frame_lineno=self.tb_lineno
        );
    }
    return py_error("AttributeError", name2);
}

impl PyTracebackFrame.tp_getattro(name2: str) -> PyObj {
    if name2 == "__class__" {
        return py_exception_type("frame");
    }
    if name2 == "f_code" {
        if self.frame_code is not None {
            return self.frame_code as PyObj;
        }
        return py_none();
    }
    if name2 == "f_lineno" {
        return PyInt(t="int", val=self.frame_lineno);
    }
    if name2 == "f_back" {
        return py_none();
    }
    return py_error("AttributeError", name2);
}

impl is_builtin_exception_name(name: str) -> bool {
    return name == "BaseException" or name in EXC_PARENT;
}

impl exc_is_subclass_of(name: str, base: str) -> bool {
    if name == base {
        return True;
    }
    cur = name;
    while cur in EXC_PARENT {
        if cur in EXC_EXTRA_PARENTS
            and exc_is_subclass_of(EXC_EXTRA_PARENTS[cur], base) {
            return True;
        }
        cur = EXC_PARENT[cur];
        if cur == base {
            return True;
        }
    }
    return False;
}

impl _exc_field_int(fields: dict[str, PyObj], key: str) -> int {
    if key in fields {
        v = fields[key];
        if isinstance(v, PyInt) {
            return (v as PyInt).val;
        }
    }
    return -1;
}

impl _exc_field_str(fields: dict[str, PyObj], key: str) -> str {
    if key in fields {
        v = fields[key];
        if isinstance(v, PyStr) {
            return (v as PyStr).val;
        }
        if isinstance(v, PyInt) {
            return str((v as PyInt).val);
        }
    }
    return "";
}

impl _exc_has_value(fields: dict[str, PyObj], key: str) -> bool {
    return key in fields and not isinstance(fields[key], PyNoneType);
}

impl _oserror_parse(args: list[PyObj]) -> dict[str, PyObj] {
    fields: dict[str, PyObj] = {};
    fields["errno"] = py_none();
    fields["strerror"] = py_none();
    fields["filename"] = py_none();
    fields["filename2"] = py_none();
    n = len(args);
    if n == 0 {
        return fields;
    }
    if n == 1 {
        if isinstance(args[0], PyInt) {
            fields["errno"] = args[0];
        }
        return fields;
    }
    fields["errno"] = args[0];
    fields["strerror"] = args[1];

    fields["filename"] = args[2] if n >= 3 else py_none();
    fields["filename2"] = args[4] if n >= 5 else py_none();
    return fields;
}

impl _construct_oserror(name: str, args: list[PyObj]) -> PyException {
    type_name = name;
    if name == "OSError" and len(args) >= 2 and isinstance(args[0], PyInt) {
        mapped = OSERROR_ERRNO_MAP.get((args[0] as PyInt).val);
        if mapped is not None {
            type_name = mapped;
        }
    }
    parsed = _oserror_parse(args);

    exc_args: list[PyObj] = [];
    if len(args) <= 1 {
        exc_args.extend(args);
    } else {
        exc_args.extend([args[0], args[1]]);
    }
    message = "";
    if len(exc_args) == 1 {
        message = expect_str(exc_args[0]);
    }
    return PyException(
        t="exception",
        type_name=type_name,
        message=message,
        args=exc_args,
        type_fields=parsed
    );
}

impl _construct_import_error(
    name: str, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyException {
    fields: dict[str, PyObj] = {};
    if "name" in kwargs {
        fields["name"] = kwargs["name"];
    } elif len(args) >= 2 {
        fields["name"] = args[1];
    } else {
        fields["name"] = py_none();
    }
    if "path" in kwargs {
        fields["path"] = kwargs["path"];
    } elif len(args) >= 3 {
        fields["path"] = args[2];
    } else {
        fields["path"] = py_none();
    }
    exc_args: list[PyObj] = [];
    exc_args.extend(args);
    message = "";
    if len(args) == 1 {
        message = expect_str(args[0]);
    }
    return PyException(
        t="exception",
        type_name=name,
        message=message,
        args=exc_args,
        type_fields=fields
    );
}

impl _construct_syntax_error(name: str, args: list[PyObj]) -> PyException {
    fields: dict[str, PyObj] = {};
    if len(args) > 0 {
        fields["msg"] = args[0];
    } else {
        fields["msg"] = py_none();
    }
    if len(args) > 1 {
        info = args[1];
        if isinstance(info, PyTuple) {
            items = (info as PyTuple).items;
            labels = ["filename", "lineno", "offset", "text"];
            for i in range(len(labels)) {
                if i < len(items) {
                    fields[labels[i]] = items[i];
                } else {
                    fields[labels[i]] = py_none();
                }
            }
        }
    }
    exc_args: list[PyObj] = [];
    exc_args.extend(args);
    message = "";
    if len(args) == 1 {
        message = expect_str(args[0]);
    }
    return PyException(
        t="exception",
        type_name=name,
        message=message,
        args=exc_args,
        type_fields=fields
    );
}

impl _construct_unicode_error(name: str, args: list[PyObj]) -> PyObj {
    if len(args) != 5 {
        kind = "Decode";
        if name == "UnicodeEncodeError" {
            kind = "Encode";
        } elif name == "UnicodeTranslateError" {
            kind = "Translate";
        }
        return py_error(
            "TypeError",
            "Unicode" + kind + "Error constructor takes exactly 5 arguments"
        );
    }
    fields: dict[str, PyObj] = {};
    keys = ["encoding", "object", "start", "end", "reason"];
    for i in range(len(keys)) {
        fields[keys[i]] = args[i];
    }
    exc_args: list[PyObj] = [];
    exc_args.extend(args);
    message = "";
    if len(args) == 1 {
        message = expect_str(args[0]);
    }
    return PyException(
        t="exception",
        type_name=name,
        message=message,
        args=exc_args,
        type_fields=fields
    );
}

impl _py_sequence_tuple(o: PyObj, out: list[PyObj]) -> bool {
    if isinstance(o, PyTuple) {
        out.extend((o as PyTuple).items);
        return True;
    }
    if isinstance(o, PyList) {
        out.extend((o as PyList).items);
        return True;
    }
    if isinstance(o, PyStr) {
        for ch in (o as PyStr).val {
            out.append(PyStr(t="str", val=ch));
        }
        return True;
    }
    if isinstance(o, PyDict) {
        _dict_ensure_order(o as PyDict);
        d = o as PyDict;
        for sk in d.order {
            out.append(d.items[sk].key);
        }
        return True;
    }
    return False;
}

impl _construct_exc_group(
    name: str, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyObj {
    if len(args) != 2 {
        return py_error(
            "TypeError",
            "BaseExceptionGroup.__new__() takes exactly 2 arguments ("
                + str(len(args))
                + " given)",
        );
    }
    if args[0].t != "str" {
        return py_error(
            "TypeError",
            "BaseExceptionGroup.__new__() argument 1 must be str, not " + args[0].t,
        );
    }
    seq_items: list[PyObj] = [];
    if not _py_sequence_tuple(args[1], seq_items) {
        return py_error("TypeError", "second argument (exceptions) must be a sequence");
    }
    items: list[PyObj] = [];
    has_base_leaf = False;
    for idx in range(len(seq_items)) {
        item = seq_items[idx];

        if item.t != "exception" {
            return py_error(
                "ValueError",
                "Item "
                    + str(idx)
                    + " of second argument (exceptions) is not an exception",
            );
        }
        leaf_name = (item as PyException).type_name;
        if not exc_is_subclass_of(leaf_name, "Exception") {
            has_base_leaf = True;
        }
        items.append(item);
    }
    if len(items) == 0 {
        return py_error(
            "ValueError", "second argument (exceptions) must be a non-empty sequence"
        );
    }
    final_name = name;
    if has_base_leaf {
        if exc_is_subclass_of(name, "ExceptionGroup") {
            return py_error(
                "TypeError", "Cannot nest BaseExceptions in an ExceptionGroup"
            );
        }
    } elif name == "BaseExceptionGroup" {
        final_name = "ExceptionGroup";
    }
    if len(kwargs) > 0 {
        return py_error("TypeError", final_name + "() takes no keyword arguments");
    }

    exc_args: list[PyObj] = [args[0]];
    arg_list_items: list[PyObj] = [];
    arg_list_items.extend(items);
    exc_args.append(PyList(t="list", items=arg_list_items));
    excs_copy: list[PyObj] = [];
    excs_copy.extend(items);
    return PyExcGroup(
        t="exception",
        type_name=final_name,
        message=(args[0] as PyStr).val,
        args=exc_args,
        excs=excs_copy
    );
}

impl PyExceptionType.tp_getattro(name2: str) -> PyObj {
    if name2 == "__name__" or name2 == "__qualname__" {
        return PyStr(t="str", val=self.name);
    }

    if name2 == "split" or name2 == "subgroup" {
        return PyEgroupTypeMember(t="egroup_type_member", name=name2);
    }
    return py_error("AttributeError", name2);
}

impl PyExceptionType.tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if self.name != "Exception"
        and self.name != "BaseException"
        and exc_is_subclass_of(self.name, "OSError") {
        if len(kwargs) > 0 {
            return py_error("TypeError", self.name + "() takes no keyword arguments");
        }
        return _construct_oserror(self.name, args);
    }

    if self.name == "ImportError" or self.name == "ModuleNotFoundError" {
        return _construct_import_error(self.name, args, kwargs);
    }
    if self.name == "BaseExceptionGroup"
        or self.name == "ExceptionGroup"
        or exc_is_subclass_of(self.name, "BaseExceptionGroup") {
        return _construct_exc_group(self.name, args, kwargs);
    }

    if len(kwargs) > 0 {
        return py_error("TypeError", self.name + "() takes no keyword arguments");
    }
    if exc_is_subclass_of(self.name, "SyntaxError") {
        return _construct_syntax_error(self.name, args);
    }
    if self.name == "UnicodeDecodeError"
        or self.name == "UnicodeEncodeError"
        or self.name == "UnicodeTranslateError" {
        return _construct_unicode_error(self.name, args);
    }

    message = "";
    if len(args) == 1 {
        message = expect_str(args[0]);
    }
    exc_args: list[PyObj] = [];
    exc_args.extend(args);

    si_value: PyObj = py_none();
    if self.name == "StopIteration" or exc_is_subclass_of(self.name, "StopIteration") {
        if len(args) > 0 {
            si_value = args[0];
        }
    }
    return PyException(
        t="exception",
        type_name=self.name,
        message=message,
        args=exc_args,
        value=si_value
    );
}

impl ExcSetStateFn.tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(args) != 1 or len(kwargs) > 0 {
        return py_error("TypeError", "__setstate__() takes exactly 1 argument");
    }
    if not isinstance(args[0], PyDict) {
        return py_error(
            "TypeError",
            "__setstate__() argument must be a dict, not '" + args[0].t + "'"
        );
    }
    state = args[0] as PyDict;
    rest: list[tuple[str, PyObj]] = [];
    for skey in state.items {
        sval = state.items[skey].value;
        if isinstance(skey, PyStr) {
            if (skey as PyStr).val == "args" {
                set = self.exc.tp_setattro("args", sval);
                if is_error(set) {
                    return set;
                }
                continue;
            }
            rest.append(((skey as PyStr).val, sval));
        }
    }
    for pair in rest {
        set = self.exc.tp_setattro(pair[0], pair[1]);
        if is_error(set) {
            self.exc.type_fields[pair[0]] = pair[1];
        }
    }
    return py_none();
}

impl _exception_args_from_value(value: PyObj) -> PyObj {
    items: list[PyObj] = [];
    if isinstance(value, PyTuple) {
        items.extend((value as PyTuple).items);
        return PyTuple(t="tuple", items=items);
    }
    if isinstance(value, PyList) {
        items.extend((value as PyList).items);
        return PyTuple(t="tuple", items=items);
    }
    return py_error("TypeError", "'" + value.t + "' object is not iterable");
}

impl PyException.tp_getattro(name: str) -> PyObj {
    if name == "args" {
        items: list[PyObj] = [];
        items.extend(self.args);
        return PyTuple(t="tuple", items=items);
    }
    if name == "__setstate__" {
        return ExcSetStateFn(t="exc_setstate_fn", exc=self);
    }
    if name == "value" {
        if self.value is not None {
            return self.value as PyObj;
        }
        return py_none();
    }
    if self.raw is not None {
        r = (self.raw as PyObj).tp_getattro(name);
        if not is_error(r) {
            return r;
        }
    }
    if name == "__cause__" {
        if self.cause is not None {
            return self.cause as PyObj;
        }
        return py_none();
    }
    if name == "__context__" {
        if self.context is not None {
            return self.context as PyObj;
        }
        return py_none();
    }

    if name == "__class__" {
        if self.raw is not None {
            raw_obj = self.raw as PyObj;
            if raw_obj.t == "instance" {
                return raw_obj.tp_getattro("__class__");
            }
        }
        return py_exception_type(self.type_name);
    }
    if name == "__traceback__" {
        if self.traceback is not None {
            return self.traceback as PyObj;
        }
        return py_none();
    }
    if name == "__suppress_context__" {
        if self.suppress_context is not None {
            return self.suppress_context as PyObj;
        }

        return PyBool(t="bool", val=False);
    }

    if name == "__notes__" {
        stored = self.type_fields.get("__notes__");
        if stored is not None and isinstance(stored, PyList) {
            items: list[PyObj] = [];
            items.extend((stored as PyList).items);
            return PyList(t="list", items=items);
        }
        return PyList(t="list", items=[]);
    }
    if name in self.type_fields {
        return self.type_fields[name];
    }

    if name == "errno"
        or name == "strerror"
        or name == "filename"
        or name == "filename2" {
        if self.family == "OSError" or exc_is_subclass_of(self.type_name, "OSError") {
            return py_none();
        }
    }
    return py_error("AttributeError", name);
}

impl PyException.tp_setattro(name: str, value: PyObj) -> PyObj {
    if name == "args" {
        coerced = _exception_args_from_value(value);
        if is_error(coerced) {
            return coerced;
        }
        items = (coerced as PyTuple).items;
        self.args = [];
        self.args.extend(items);

        if self.raw is not None {
            raw_obj = self.raw as PyObj;
            if raw_obj.t == "instance" {
                stored: list[PyObj] = [];
                stored.extend(items);
                raw_obj.tp_setattro("args", PyTuple(t="tuple", items=stored));
            }
        }
        return py_none();
    }
    if name == "__traceback__" {
        if not isinstance(value, PyTraceback) and value.t != "none" {
            return py_error("TypeError", "__traceback__ must be a traceback or None");
        }
        self.traceback = value;
        return py_none();
    }
    if name == "__cause__" {
        if value.t != "none" and value.t != "exception" {
            return py_error(
                "TypeError", "exception cause must be None or derive from BaseException"
            );
        }
        self.cause = value;
        if value.t != "none" {
            self.suppress_context = PyBool(t="bool", val=True);
        }
        return py_none();
    }
    if name == "__context__" {
        if value.t != "none" and value.t != "exception" {
            return py_error(
                "TypeError",
                "exception context must be None or derive from BaseException"
            );
        }
        self.context = value;
        return py_none();
    }
    if name == "__suppress_context__" {
        if not isinstance(value, PyBool) {
            return py_error("TypeError", "attribute value type must be bool");
        }
        self.suppress_context = value;
        return py_none();
    }
    return py_error("AttributeError", name);
}

impl PyExcGroup.tp_getattro(name: str) -> PyObj {
    if name == "message" {
        return PyStr(t="str", val=self.message);
    }
    if name == "exceptions" {
        items: list[PyObj] = [];
        items.extend(self.excs);
        return PyTuple(t="tuple", items=items);
    }
    return PyException.tp_getattro(self, name);
}

impl PyExcGroup.tp_setattro(name: str, value: PyObj) -> PyObj {
    if name == "message" or name == "exceptions" {
        return py_error("AttributeError", "readonly attribute");
    }
    return PyException.tp_setattro(self, name, value);
}

impl PyIter.tp_iter -> PyObj {
    return self;
}

impl PyCallableIter.tp_iter -> PyObj {
    return self;
}

impl PySeqIter.tp_iter -> PyObj {
    return self;
}

impl PySeqIter.tp_getattro(name: str) -> PyObj {
    if name == "__setstate__" {
        return PySeqIterSetState(t="seqiter_setstate", it=self);
    }
    return py_error("AttributeError", name);
}

impl PySeqIterSetState.tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", "__setstate__() takes no keyword arguments");
    }
    if len(args) != 1 {
        return py_error(
            "TypeError", "__setstate__() takes exactly one argument (index)"
        );
    }
    iv = args[0].to_index();
    if is_error(iv) {
        return iv;
    }
    self.it.index = (iv as PyInt).val;
    return py_none();
}

impl bytes_value(o: PyObj) -> list[int] {
    if isinstance(o, PyBytes) {
        return (o as PyBytes).val;
    }
    return [];
}

impl tuple_value(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyTuple) {
        return (o as PyTuple).items;
    }
    return [];
}

impl str_value(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    return "";
}

impl str_values(o: PyObj) -> list[str] {
    result: list[str] = [];
    for it in tuple_value(o) {
        result.append(str_value(it));
    }
    return result;
}

impl int_values(o: PyObj) -> list[int] {
    result: list[int] = [];
    for it in tuple_value(o) {
        if isinstance(it, PyInt) {
            result.append((it as PyInt).val);
        }
    }
    return result;
}

impl _cmp_int_vs_float(a: int, fv: float) -> int {
    t = int(fv);
    frac = fv - float(t);
    if a < t {
        return -1;
    }
    if a > t {
        return 1;
    }
    if frac > 0.0 {
        return -1;
    }
    if frac < 0.0 {
        return 1;
    }
    return 0;
}

impl expect_int(o: PyObj) -> int {
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    return 0;
}

impl expect_str(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    return "";
}

impl _repr_hex2(n: int) -> str {
    return "0123456789abcdef"[n];
}

impl _repr_unicode_escape(cp: int) -> str {
    if cp < 256 {
        return ("\\x" + _repr_hex2((cp >> 4) & 15) + _repr_hex2(cp & 15));
    }
    if cp <= 0xFFFF {
        out = "\\u";
        shift = 12;
        while shift >= 0 {
            out = out + _repr_hex2((cp >> shift) & 15);
            shift = shift - 4;
        }
        return out;
    }
    out = "\\U";
    shift = 28;
    while shift >= 0 {
        out = out + _repr_hex2((cp >> shift) & 15);
        shift = shift - 4;
    }
    return out;
}

impl _repr_unicode_char(ch: str, quote: int) -> str {
    if ch == "\\" {
        return "\\\\";
    }
    if quote == 39 and ch == "'" {
        return "\\'";
    }
    if quote == 34 and ch == "\"" {
        return "\\\"";
    }
    if ch == "\t" {
        return "\\t";
    }
    if ch == "\n" {
        return "\\n";
    }
    if ch == "\r" {
        return "\\r";
    }
    if ch.isprintable() {
        return ch;
    }
    return _repr_unicode_escape(ord(ch));
}

impl str_repr_text(val: str) -> str {
    if len(val) == 0 {
        return "''";
    }
    squotes = 0;
    dquotes = 0;
    i = 0;
    while i < len(val) {
        if val[i] == "'" {
            squotes = squotes + 1;
        } elif val[i] == "\"" {
            dquotes = dquotes + 1;
        }
        i = i + 1;
    }
    quote = 39;
    if squotes > 0 and dquotes == 0 {
        quote = 34;
    }
    out = "";
    if quote == 39 {
        out = "'";
    } else {
        out = "\"";
    }
    i = 0;
    while i < len(val) {
        out = out + _repr_unicode_char(val[i], quote);
        i = i + 1;
    }
    if quote == 39 {
        out = out + "'";
    } else {
        out = out + "\"";
    }
    return out;
}

impl dict_key_repr(index: PyObj) -> str {
    if isinstance(index, PyStr) {
        return str_repr_text((index as PyStr).val);
    }
    if isinstance(index, PyInt) {
        return str((index as PyInt).val);
    }
    hkr = index.tp_hashkey();
    if is_error(hkr) {
        return "<unhashable>";
    }
    return hashkey_str(hkr);
}

impl expect_float(o: PyObj) -> float {
    if isinstance(o, PyFloat) {
        return (o as PyFloat).val;
    }
    return 0.0;
}

impl expect_bool(o: PyObj) -> bool {
    if isinstance(o, PyBool) {
        return (o as PyBool).val;
    }
    return False;
}

impl list_value(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyList) {
        return (o as PyList).items;
    }
    return [];
}

impl concat_items(left: list[PyObj], right: list[PyObj]) -> list[PyObj] {
    result: list[PyObj] = [];
    result.extend(left);
    result.extend(right);
    return result;
}

impl find_name(names: list[str], name: str) -> int {
    i = 0;
    while i < len(names) {
        if names[i] == name {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

impl py_none -> PyObj {
    return PyNoneType(t="none");
}

impl py_error(type_name: str, message: str) -> PyObj {
    return PyError(
        t="error",
        exception=PyException(t="exception", type_name=type_name, message=message),
    );
}

impl py_error_with_args(type_name: str, message: str, args: list[PyObj]) -> PyObj {
    exc_args: list[PyObj] = [];
    exc_args.extend(args);
    return PyError(
        t="error",
        exception=PyException(
            t="exception", type_name=type_name, message=message, args=exc_args
        ),
    );
}

impl py_exception_type(name: str) -> PyObj {
    return PyExceptionType(t="exception_type", name=name);
}

impl hashkey_str(hk_res: PyObj) -> str {
    return (hk_res as PyStr).val;
}

impl hashkey_equal(a: PyObj, b: PyObj) -> bool {
    if isinstance(a, PyStr) and isinstance(b, PyStr) {
        return (a as PyStr).val == (b as PyStr).val;
    }
    return False;
}

impl is_error(value: PyObj) -> bool {
    return value.t == "error";
}

impl _zero_step_error(sl: PySlice) -> PyObj {
    if isinstance(sl.step, PyNoneType) {
        return py_none();
    }
    step = sl.step;
    if isinstance(step, PyBool) {
        if (step as PyBool).val {
            return py_none();
        }
        return py_error("ValueError", "slice step cannot be zero");
    }
    if isinstance(step, PyInt) and (step as PyInt).val == 0 {
        return py_error("ValueError", "slice step cannot be zero");
    }
    return py_none();
}

impl _adjust_index(i: int, length: int, neg: bool) -> int {
    if i < 0 {
        i = i + length;
        if i < 0 {
            if neg {
                i = -1;
            } else {
                i = 0;
            }
        }
    } elif i >= length {
        if neg {
            i = length - 1;
        } else {
            i = length;
        }
    }
    return i;
}

impl _seq_index(index: PyObj, length: int, type_err: str, index_err: str) -> PyObj {
    idx = index.to_index();
    if is_error(idx) {
        return py_error("TypeError", type_err);
    }
    i = (idx as PyInt).val;
    if i < 0 {
        i = length + i;
    }
    if i >= 0 and i < length {
        return PyInt(t="int", val=i);
    }
    return py_error("IndexError", index_err);
}

impl slice_indices(sl: PySlice, length: int) -> list[int] {
    step = 1;
    if not isinstance(sl.step, PyNoneType) {
        step = expect_int(sl.step);
    }

    if step == 0 {
        raise ValueError("slice step cannot be zero");
    }
    neg = step < 0;
    start = 0;
    if isinstance(sl.start, PyNoneType) {
        if neg {
            start = length - 1;
        } else {
            start = 0;
        }
    } else {
        start = _adjust_index(expect_int(sl.start), length, neg);
    }
    stop = 0;
    if isinstance(sl.stop, PyNoneType) {
        if neg {
            stop = -1;
        } else {
            stop = length;
        }
    } else {
        stop = _adjust_index(expect_int(sl.stop), length, neg);
    }
    return [start, stop, step];
}

impl _slice_positions(length: int, sl: PySlice) -> list[int] {
    b = slice_indices(sl, length);
    i = b[0];
    stop = b[1];
    step = b[2];
    out: list[int] = [];
    if step > 0 {
        while i < stop {
            out.append(i);
            i = i + step;
        }
    } else {
        while i > stop {
            out.append(i);
            i = i + step;
        }
    }
    return out;
}

impl _slice_objs(items: list[PyObj], sl: PySlice) -> list[PyObj] {
    out: list[PyObj] = [];
    for i in _slice_positions(len(items), sl) {
        out.append(items[i]);
    }
    return out;
}

impl _slice_ints(vals: list[int], sl: PySlice) -> list[int] {
    out: list[int] = [];
    for i in _slice_positions(len(vals), sl) {
        out.append(vals[i]);
    }
    return out;
}

impl _slice_str(s: str, sl: PySlice) -> str {
    out = "";
    for i in _slice_positions(len(s), sl) {
        out = out + s[i];
    }
    return out;
}

impl _digit_val(c: str) -> int {
    digits = "0123456789";
    j = 0;
    while j < 10 {
        if digits[j] == c {
            return j;
        }
        j = j + 1;
    }
    return -1;
}

impl _is_digit(c: str) -> bool {
    return _digit_val(c) >= 0;
}

impl _uint_to_str(n: int, base: int, digits: str) -> str {
    if n == 0 {
        return "0";
    }
    out = "";
    while n > 0 {
        out = digits[n % base] + out;
        n = n // base;
    }
    return out;
}

impl _fmt_int(
    val: int, base: int, digits: str, prefix: str, flags: int, prec: int, width: int
) -> str {
    neg = val < 0;
    mag = val;
    if neg {
        mag = -val;
    }
    body = _uint_to_str(mag, base, digits);
    if prec >= 0 {
        while len(body) < prec {
            body = "0" + body;
        }
    }
    sign = "";
    if neg {
        sign = "-";
    } elif (flags & F_PLUS) != 0 {
        sign = "+";
    } elif (flags & F_SPACE) != 0 {
        sign = " ";
    }
    pfx = "";
    if (flags & F_HASH) != 0 and mag != 0 {
        pfx = prefix;
    }

    if (flags & F_ZERO) != 0 and (flags & F_MINUS) == 0 and prec < 0 {
        total = len(sign) + len(pfx) + len(body);
        while total < width {
            body = "0" + body;
            total = total + 1;
        }
    }
    return sign + pfx + body;
}

impl _int_of(o: PyObj) -> int {
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return 1;
        }
        return 0;
    }
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    return 0;
}

impl _is_intlike(o: PyObj) -> bool {
    return isinstance(o, PyInt) or isinstance(o, PyBool);
}

impl _pyobj_str(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return "True";
        }
        return "False";
    }
    if isinstance(o, PyInt) {
        return _fmt_int((o as PyInt).val, 10, "0123456789", "", 0, -1, 0);
    }
    if isinstance(o, PyNoneType) {
        return "None";
    }
    return "<object>";
}

impl _pyobj_repr(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return str_repr_text((o as PyStr).val);
    }
    return _pyobj_str(o);
}

impl _pad_spaces(s: str, width: int, left: bool) -> str {
    while len(s) < width {
        if left {
            s = s + " ";
        } else {
            s = " " + s;
        }
    }
    return s;
}

impl _trunc(s: str, prec: int) -> str {
    if prec < 0 or len(s) <= prec {
        return s;
    }
    out = "";
    i = 0;
    while i < prec {
        out = out + s[i];
        i = i + 1;
    }
    return out;
}

impl str_mod_format(fmt: str, args: PyObj) -> PyObj {
    argv: list[PyObj] = [];
    mapping = False;
    if isinstance(args, PyTuple) {
        argv = (args as PyTuple).items;
    } elif isinstance(args, PyDict) {
        mapping = True;
    } else {
        argv.append(args);
    }
    ai = 0;
    out = "";
    n = len(fmt);
    i = 0;
    while i < n {
        c = fmt[i];
        if c != "%" {
            out = out + c;
            i = i + 1;
            continue;
        }
        i = i + 1;
        if i >= n {
            return py_error("ValueError", "incomplete format");
        }
        if fmt[i] == "%" {
            out = out + "%";
            i = i + 1;
            continue;
        }
        key = "";
        haskey = False;
        if fmt[i] == "(" {
            i = i + 1;
            while i < n and fmt[i] != ")" {
                key = key + fmt[i];
                i = i + 1;
            }
            if i >= n {
                return py_error("ValueError", "incomplete format key");
            }
            i = i + 1;
            haskey = True;
        }
        flags = 0;
        while i < n {
            f = fmt[i];
            if f == "-" {
                flags = flags | F_MINUS;
                i = i + 1;
            } elif f == "+" {
                flags = flags | F_PLUS;
                i = i + 1;
            } elif f == " " {
                flags = flags | F_SPACE;
                i = i + 1;
            } elif f == "0" {
                flags = flags | F_ZERO;
                i = i + 1;
            } elif f == "#" {
                flags = flags | F_HASH;
                i = i + 1;
            } else {
                break;
            }
        }
        fminus = (flags & F_MINUS) != 0;
        width = 0;
        while i < n and _is_digit(fmt[i]) {
            width = width * 10 + _digit_val(fmt[i]);
            i = i + 1;
        }
        prec = -1;
        if i < n and fmt[i] == "." {
            i = i + 1;
            prec = 0;
            while i < n and _is_digit(fmt[i]) {
                prec = prec * 10 + _digit_val(fmt[i]);
                i = i + 1;
            }
        }
        while i < n and (fmt[i] == "l" or fmt[i] == "h" or fmt[i] == "L") {
            i = i + 1;
        }
        if i >= n {
            return py_error("ValueError", "incomplete format");
        }
        conv = fmt[i];
        i = i + 1;

        arg: PyObj = py_none();
        if haskey {
            if not mapping {
                return py_error("TypeError", "format requires a mapping");
            }
            d = (args as PyDict).dict_str_map();
            if key in d {
                arg = d[key];
            } else {
                return py_error("KeyError", key);
            }
        } else {
            if ai >= len(argv) {
                return py_error("TypeError", "not enough arguments for format string");
            }
            arg = argv[ai];
            ai = ai + 1;
        }

        piece = "";
        if conv == "d" or conv == "i" or conv == "u" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%d format: a number is required");
            }
            piece = _fmt_int(_int_of(arg), 10, "0123456789", "", flags, prec, width);
        } elif conv == "x" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%x format: an integer is required");
            }
            piece = _fmt_int(
                _int_of(arg), 16, "0123456789abcdef", "0x", flags, prec, width
            );
        } elif conv == "X" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%X format: an integer is required");
            }
            piece = _fmt_int(
                _int_of(arg), 16, "0123456789ABCDEF", "0X", flags, prec, width
            );
        } elif conv == "o" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%o format: an integer is required");
            }
            piece = _fmt_int(_int_of(arg), 8, "01234567", "0o", flags, prec, width);
        } elif conv == "c" {
            if _is_intlike(arg) {
                piece = chr(_int_of(arg));
            } elif isinstance(arg, PyStr) {
                piece = (arg as PyStr).val;
            } else {
                return py_error("TypeError", "%c requires int or char");
            }
        } elif conv == "s" {
            piece = _trunc(_pyobj_str(arg), prec);
        } elif conv == "r" {
            piece = _trunc(_pyobj_repr(arg), prec);
        } else {
            return py_error("ValueError", "unsupported format character");
        }
        out = out + _pad_spaces(piece, width, fminus);
    }
    if (not mapping) and ai < len(argv) {
        return py_error(
            "TypeError", "not all arguments converted during string formatting"
        );
    }
    return PyStr(t="str", val=out);
}

impl ShimTypeMarker.tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    return (self.ctor as PyObj).tp_call(args, kwargs);
}

impl ShimTypeMarker.tp_getattro(name2: str) -> PyObj {
    if name2 == "__jac_shim_tag__" {
        return PyStr(t="str", val=self.tag);
    }
    return (self.ctor as PyObj).tp_getattro(name2);
}
