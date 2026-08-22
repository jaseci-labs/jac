# c2jac: 29 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L204 [W4201] cast to `stwodigits` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L222 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L246 [W4201] cast to `uintptr_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L258 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L283 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L283 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L288 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L288 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L302 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L302 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L308 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L308 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L334 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L334 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L339 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L339 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L384 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L384 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L390 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L390 [W4201] cast to `digit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L411 [W4201] cast to `sdigit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L411 [W4201] cast to `sdigit` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L430 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L431 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L432 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L434 [W4201] cast to `Py_hash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L447 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L448 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L449 [W4201] cast to `Py_hash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied

glob ptrdiff_t = int,
     size_t = int,
     ssize_t = int,
     intptr_t = int,
     uintptr_t = int,
     int8_t = int,
     uint8_t = int,
     int16_t = int,
     uint16_t = int,
     int32_t = int,
     uint32_t = int,
     int64_t = int,
     uint64_t = int,
     intmax_t = int,
     uintmax_t = int,
     int_least8_t = int,
     uint_least8_t = int,
     int_least16_t = int,
     uint_least16_t = int,
     int_least32_t = int,
     uint_least32_t = int,
     int_least64_t = int,
     uint_least64_t = int,
     int_fast8_t = int,
     uint_fast8_t = int,
     int_fast16_t = int,
     uint_fast16_t = int,
     int_fast32_t = int,
     uint_fast32_t = int,
     int_fast64_t = int,
     uint_fast64_t = int,
     Py_ssize_t = int,
     Py_hash_t = int,
     digit = int,
     stwodigits = int,
     sdigit = int,
     _Pyuintptr_t = int,
     Py_uhash_t = int;


@__jac_value__
obj lenfunc {
    def call -> int {
        ;
    }
}

@__jac_value__
obj unaryfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj binaryfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj inquiry {
    def call -> int {
        ;
    }
}

@__jac_value__
obj vectorcallfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj hashfunc {
    def call -> int {
        ;
    }
}

@__jac_value__
obj richcmpfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj getiterfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj iternextfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj PySequenceMethods {
    has sq_length: lenfunc = lenfunc();
}

@__jac_value__
obj PyNumberMethods {
    has nb_add: binaryfunc = binaryfunc(),
        nb_subtract: binaryfunc = binaryfunc(),
        nb_multiply: binaryfunc = binaryfunc(),
        nb_remainder: binaryfunc = binaryfunc(),
        nb_divmod: binaryfunc = binaryfunc(),
        nb_power: binaryfunc = binaryfunc(),
        nb_negative: binaryfunc = binaryfunc(),
        nb_positive: binaryfunc = binaryfunc(),
        nb_absolute: binaryfunc = binaryfunc(),
        nb_bool: inquiry = inquiry(),
        nb_invert: unaryfunc = unaryfunc(),
        nb_lshift: binaryfunc = binaryfunc(),
        nb_rshift: binaryfunc = binaryfunc(),
        nb_and: binaryfunc = binaryfunc(),
        nb_xor: binaryfunc = binaryfunc(),
        nb_or: binaryfunc = binaryfunc();
}

@__jac_value__
obj PyObject {
    has ob_type: PyTypeObject = PyTypeObject();
}

@__jac_value__
obj PyTypeObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0,
        tp_name: str = str(),
        tp_basicsize: int = 0,
        tp_itemsize: int = 0,
        tp_dealloc: object = object(),
        tp_repr: unaryfunc = unaryfunc(),
        tp_as_number: PyNumberMethods = PyNumberMethods(),
        tp_as_sequence: PySequenceMethods = PySequenceMethods(),
        tp_hash: hashfunc = hashfunc(),
        tp_richcompare: richcmpfunc = richcmpfunc(),
        tp_iter: getiterfunc = getiterfunc(),
        tp_iternext: iternextfunc = iternextfunc(),
        tp_flags: int = 0,
        tp_doc: str = str(),
        tp_base: PyTypeObject = PyTypeObject(),
        tp_vectorcall: vectorcallfunc = vectorcallfunc();
}

@__jac_value__
obj _PyLongValue {
    has lv_tag: int = 0,
        ob_digit: list = list();
}

@__jac_value__
obj PyLongObject {
    has ob_base: PyObject = PyObject(),
        long_value: _PyLongValue = _PyLongValue();
}


def _PyLong_IsCompact(op: PyLongObject) -> int {
    return ((op.long_value.lv_tag & 3) == 0);
}

def _PyLong_CompactValue(op: PyLongObject) -> stwodigits {
    return (op.long_value.lv_tag >> 2);
}

def _PyLong_IsNegative(op: PyLongObject) -> int {
    if _PyLong_IsCompact(op) {
        return (_PyLong_CompactValue(op) < 0);
    }

    return ((op.long_value.lv_tag & 3) == 2);
}

def _PyLong_DigitCount(op: PyLongObject) -> int {
    if _PyLong_IsCompact(op) {
        return 1;
    }

    return (op.long_value.lv_tag >> 3);
}

def _PyLong_SignedDigitCount(op: PyLongObject) -> int {
    n: int = _PyLong_DigitCount(op);
    if _PyLong_IsNegative(op) {
        return -n;
    }

    return n;
}

def _PyLong_BothAreCompact(a: PyLongObject, b: PyLongObject) -> int {
    return (_PyLong_IsCompact(a) and _PyLong_IsCompact(b));
}

def _PyLong_FlipSign(op: PyLongObject) -> None {
    if _PyLong_IsCompact(op) {
        v: stwodigits = _PyLong_CompactValue(op);
        op.long_value.lv_tag = -v << 2;
        return;
    }

    if _PyLong_IsNegative(op) {
        op.long_value.lv_tag &= ~3;
    } else {
        op.long_value.lv_tag |= 2;
    }
}

def long_alloc(size: int) -> PyLongObject {
    size;
    return 0;
}

def long_normalize(v: PyLongObject) -> PyLongObject {
    return v;
}

def maybe_small_long(v: PyLongObject) -> PyLongObject {
    return v;
}


def v_iadd(x: digit, m: int, y: digit, n: int) -> digit {
    i: int = 0;
    carry: digit = 0;

    for i = 0 while i < n with i += 1 {
        carry += x[i] + y[i];
        x[i] = carry & ((1 << 30) - 1);
        carry >>= 30;
    }

    while (carry and (i < m)) {
        carry += x[i];
        x[i] = carry & ((1 << 30) - 1);
        carry >>= 30;
        i += 1;
    }

    return carry;
}

def v_isub(x: digit, m: int, y: digit, n: int) -> digit {
    i: int = 0;
    borrow: digit = 0;

    for i = 0 while i < n with i += 1 {
        borrow = (x[i] - y[i]) - borrow;
        x[i] = borrow & ((1 << 30) - 1);
        borrow >>= 30;
        borrow &= 1;
    }

    while (borrow and (i < m)) {
        borrow = x[i] - borrow;
        x[i] = borrow & ((1 << 30) - 1);
        borrow >>= 30;
        borrow &= 1;
        i += 1;
    }

    return borrow;
}

def x_add(a: PyLongObject, b: PyLongObject) -> PyLongObject {
    size_a: int = _PyLong_DigitCount(a);
    size_b: int = _PyLong_DigitCount(b);
    z: PyLongObject = PyLongObject();
    i: int = 0;
    carry: digit = 0;

    if (size_a < size_b) {
        temp: PyLongObject = a;
        a = b;
        b = temp;
        size_temp: int = size_a;
        size_a = size_b;
        size_b = size_temp;
    }

    z = long_alloc((size_a + 1));
    if (z == 0) {
        return 0;
    }
    for i = 0 while i < size_b with i += 1 {
        carry += a.long_value.ob_digit[i] + b.long_value.ob_digit[i];
        z.long_value.ob_digit[i] = carry & ((1 << 30) - 1);
        carry >>= 30;
    }

    while (i < size_a) {
        carry += a.long_value.ob_digit[i];
        z.long_value.ob_digit[i] = carry & ((1 << 30) - 1);
        carry >>= 30;
        i += 1;
    }

    z.long_value.ob_digit[i] = carry;
    return long_normalize(z);
}

def x_sub(a: PyLongObject, b: PyLongObject) -> PyLongObject {
    size_a: int = _PyLong_DigitCount(a);
    size_b: int = _PyLong_DigitCount(b);
    z: PyLongObject = PyLongObject();
    i: int = 0;
    sign: int = 1;
    borrow: digit = 0;

    if (size_a < size_b) {
        sign = -1;
        temp: PyLongObject = a;
        a = b;
        b = temp;
        size_temp: int = size_a;
        size_a = size_b;
        size_b = size_temp;
    } elif (size_a == size_b) {
        i = size_a;
        while (
            ((i := i - 1) >= 0)
            and (a.long_value.ob_digit[i] == b.long_value.ob_digit[i])
        ) {
            ;
        }
        if (i < 0) {
            z = long_alloc(1);
            if (z == 0) {
                return 0;
            }
            z.long_value.ob_digit[0] = 0;
            return long_normalize(z);
        }
        if (a.long_value.ob_digit[i] < b.long_value.ob_digit[i]) {
            sign = -1;
            temp: PyLongObject = a;
            a = b;
            b = temp;
        }
        size_a = size_b=i + 1;
    }

    z = long_alloc(size_a);
    if (z == 0) {
        return 0;
    }
    for i = 0 while i < size_b with i += 1 {
        borrow = (a.long_value.ob_digit[i] - b.long_value.ob_digit[i]) - borrow;
        z.long_value.ob_digit[i] = borrow & ((1 << 30) - 1);
        borrow >>= 30;
        borrow &= 1;
    }

    while (i < size_a) {
        borrow = a.long_value.ob_digit[i] - borrow;
        z.long_value.ob_digit[i] = borrow & ((1 << 30) - 1);
        borrow >>= 30;
        borrow &= 1;
        i += 1;
    }

    if (sign < 0) {
        _PyLong_FlipSign(z);
    }

    return maybe_small_long(long_normalize(z));
}

def long_compare(a: PyLongObject, b: PyLongObject) -> int {
    if _PyLong_BothAreCompact(a, b) {
        return (_PyLong_CompactValue(a) - _PyLong_CompactValue(b));
    }

    sign: int = _PyLong_SignedDigitCount(a) - _PyLong_SignedDigitCount(b);
    if (sign == 0) {
        i: int = _PyLong_DigitCount(a);
        diff: sdigit = 0;
        while ((i := i - 1) >= 0) {
            diff = a.long_value.ob_digit[i] - b.long_value.ob_digit[i];
            if diff {
                break;
            }
        }

        sign = -diff if _PyLong_IsNegative(a) else diff;
    }

    return sign;
}

def long_hash(`obj: PyObj) -> int {
    v: PyLongObject = `obj;
    x: Py_uhash_t = Py_uhash_t();
    i: int = 0;
    sign: int = 0;

    if _PyLong_IsCompact(v) {
        x = _PyLong_CompactValue(v);
        if (x == -1) {
            x = -2;
        }

        return x;
    }

    i = _PyLong_DigitCount(v);
    sign = -1 if _PyLong_IsNegative(v) else 1;
    x = 0;
    while ((i := i - 1) >= 0) {
        x = ((x << 30) & ((1 << 61) - 1)) | (x >> (61 - 30));

        x += v.long_value.ob_digit[i];
        if (x >= ((1 << 61) - 1)) {
            x -= (1 << 61) - 1;
        }
    }

    x = x * sign;
    if (x == -1) {
        x = -2;
    }
    return x;
}

def long_richcompare(`self: PyObj, other: PyObj, op: int) -> PyObj {
    result: int = 0;
    while True {
        if (not (`self.ob_type == PyLong_Type) or not (other.ob_type == PyLong_Type)) {
            return Py_NotImplemented;
        }
        if not 0 {
            break;
        }
    }
    if (`self == other) {
        result = 0;
    } else {
        result = long_compare(`self, other);
    }
    while True {
        if op == 2 {
            if (result == 0) {
                return Py_True;
            }
            return Py_False;
        } elif op == 3 {
            if (result != 0) {
                return Py_True;
            }
            return Py_False;
        } elif op == 0 {
            if (result < 0) {
                return Py_True;
            }
            return Py_False;
        } elif op == 4 {
            if (result > 0) {
                return Py_True;
            }
            return Py_False;
        } elif op == 1 {
            if (result <= 0) {
                return Py_True;
            }
            return Py_False;
        } elif op == 5 {
            if (result >= 0) {
                return Py_True;
            }
            return Py_False;
        } else {
            PyErr_BadInternalCall();
            return 0;
        }
        if not 0 {
            break;
        }
    }
}
