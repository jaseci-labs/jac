"""Exact compiler constant identity, shared by pooling and native serialization."""
import from jaclang.runtime.python.objects {
    PyObj,
    PyInt,
    PyBool,
    PyFloat,
    PyComplex,
    PyStr,
    PyBytes,
    PyTuple,
    PySet,
    PySlice,
    PyCode
}
import from jaclang.runtime.python.compiler_integer { PyBigInt, integer_decimal }

# Normalize finite IEEE doubles using exact powers of two. This works in both
# Jac backends and avoids the native formatter rounding distinct constants to
# the same text. Zero retains its sign; callers key NaNs by object identity.
def float_key(value: float) -> str {
    if value == 0.0 {
        return "-zero" if repr(value).startswith("-") else "zero";
    }
    if value * 0.0 != 0.0 {
        return "-inf" if value < 0.0 else "inf";
    }
    negative = value < 0.0;
    magnitude = -value if negative else value;
    exponent = 0;
    while magnitude >= 2.0 {
        magnitude *= 0.5;
        exponent += 1;
    }
    while magnitude < 1.0 {
        magnitude *= 2.0;
        exponent -= 1;
    }
    mantissa = int(magnitude * 4503599627370496.0);
    return ("-" if negative else "+") + str(mantissa) + ":" + str(exponent);
}

def constant_key(value: PyObj) -> str {
    if isinstance(value, PyBigInt) {
        return "int:" + integer_decimal(value);
    }
    if isinstance(value, PyCode) {
        return "code:" + str(id(value));
    }
    if isinstance(value, PyTuple) {
        keys = [constant_key(item) for item in value.items];
        return "tuple:" + "".join(str(len(key)) + ":" + key for key in keys);
    }
    if isinstance(value, PySet) and value.frozen {
        keys = sorted([constant_key(item) for item in value.items.values()]);
        return "frozenset:" + "".join(str(len(key)) + ":" + key for key in keys);
    }
    if isinstance(value, PySlice) {
        keys = [
            constant_key(value.start),
            constant_key(value.stop),
            constant_key(value.step)
        ];
        return "slice:" + "".join(str(len(key)) + ":" + key for key in keys);
    }
    if isinstance(value, PyFloat) {
        if value.val != value.val {
            return "nan:" + str(id(value));
        }
        return "float:" + float_key(value.val);
    }
    if isinstance(value, PyComplex) {
        if value.real != value.real or value.imag != value.imag {
            return "complex-nan:" + str(id(value));
        }
        return "complex:" + float_key(value.real) + ":" + float_key(value.imag);
    }
    if isinstance(value, PyInt) {
        return "int:" + str(value.val);
    }
    if isinstance(value, PyBool) {
        return "bool:" + str(value.val);
    }
    if isinstance(value, PyStr) {
        return "str:" + value.val;
    }
    if isinstance(value, PyBytes) {
        return "bytes:" + str(value.val);
    }
    return value.t;
}
