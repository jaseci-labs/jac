# P3.2a — long core algorithms (digit vector ops, compare, hash).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/longobject_core.c``
# (lift: ``jac-py/Objects/_lifted/longobject_core.jac``).
#
# Runtime ``ceval`` uses ``PyInt.val`` (host bignum) for arithmetic; int
# compares route through PyInt.tp_richcompare. Only the CPython ``long_hash``
# digit-rotation port and ``int_repr`` are wired; the digit-vector arithmetic
# reference lives in ``Objects/_lifted/longobject_core.jac``.
import from objects { PyObj, PyInt, PyStr, is_error, _bool_from_cmp, }

glob PyLong_SHIFT: int = 30,
     PyLong_MASK: int = 1073741823,
     PyLong_BASE: int = 1073741824,
     _PyHASH_BITS: int = 61,
     _PyHASH_MODULUS: int = 2305843009213693951;


def _digit_count(abs_v: int) -> int {
    if abs_v == 0 {
        return 0;
    }
    count = 0;
    tmp = abs_v;
    while tmp > 0 {
        count = count + 1;
        tmp = tmp >> PyLong_SHIFT;
    }
    return count;
}

def _abs_digits(value: int) -> list[int] {
    abs_v = value;
    if value < 0 {
        abs_v = -value;
    }
    digits: list[int] = [];
    if abs_v == 0 {
        digits.append(0);
        return digits;
    }
    tmp = abs_v;
    while tmp > 0 {
        digits.append(tmp & PyLong_MASK);
        tmp = tmp >> PyLong_SHIFT;
    }
    return digits;
}

# CPython ``long_hash`` — compact fast path + digit rotation for bignums.
def long_hash(value: int) -> int {
    if _digit_count(value if value >= 0 else -value) <= 1 {
        if value == -1 {
            return -2;
        }
        return value;
    }
    abs_v = value;
    sign = 1;
    if value < 0 {
        sign = -1;
        abs_v = -value;
    }
    digits = _abs_digits(abs_v);
    x = 0;
    i = len(digits) - 1;
    while i >= 0 {
        x = ((x << PyLong_SHIFT) & _PyHASH_MODULUS)
            | (x >> (_PyHASH_BITS - PyLong_SHIFT));
        x = x + digits[i];
        if x >= _PyHASH_MODULUS {
            x = x - _PyHASH_MODULUS;
        }
        i = i - 1;
    }
    x = x * sign;
    if x == -1 {
        return -2;
    }
    return x;
}

def long_hash_obj(v: PyInt) -> PyObj {
    return PyInt(t="int", val=long_hash(v.val));
}

# CPython ``long_repr`` — decimal text (``str(int)`` form).
def int_repr(v: PyInt) -> PyObj {
    return PyStr(t="str", val=str(v.val));
}
