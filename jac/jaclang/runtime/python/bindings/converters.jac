"""Argument Clinic converters for native Jac bindings.

Each converter takes a borrowed argument and returns the C-level value that
CPython's generated clinic code would pass to the module's `_impl` function.
On failure the Python exception is set and boundary_failure is raised, which
the binding's invoke() turns into a NULL result. Messages follow
Python/getargs.c and Tools/clinic so upstream tests see the same text.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyErr_Occurred,
    PyFloat_AsDouble,
    PyFloat_FromDouble,
    PyIndex_Check,
    PyLong_AsInt,
    PyLong_AsLong,
    PyLong_AsLongLong,
    PyLong_AsSsize_t,
    PyLong_AsUnsignedLong,
    PyLong_AsUnsignedLongLong,
    PyLong_AsUnsignedLongLongMask,
    PyLong_AsUnsignedLongMask,
    PyLong_FromLong,
    PyLong_FromSize_t,
    PyLong_FromSsize_t,
    PyLong_FromUnsignedLong,
    PyNumber_Index,
    PyObject,
    PyObject_IsTrue,
    Py_GetConstantBorrowed,
    Py_TYPE,
    jacpy_is_float,
    jacpy_is_none,
    jacpy_is_unicode,
    jacpy_release
}
import from jaclang.runtime.python.bindings.type { jacpy_binding_base }
import from jaclang.runtime.python.capi {
    boundary_failure,
    object_error,
    text_value,
    type_name
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }

def argument_label(argname: str, position: int) -> str {
    return f"argument {position}" if not argname else f"argument '{argname}'";
}

def bad_argument(fname: str, label: str, expected: str, value: ptr[PyObject]) {
    shown = "None" if jacpy_is_none(value) != 0 else type_name(value);
    object_error("TypeError", f"{fname}() {label} must be {expected}, not {shown}");
    raise boundary_failure();
}

def failed -> bool {
    return bool(PyErr_Occurred());
}

def convert_int(value: ptr[PyObject]) -> i32 {
    result = PyLong_AsInt(value);
    if result == -1 and failed() {
        raise boundary_failure();
    }
    return result;
}

def convert_long(value: ptr[PyObject]) -> i64 {
    result = PyLong_AsLong(value);
    if result == -1 and failed() {
        raise boundary_failure();
    }
    return result;
}

def convert_long_long(value: ptr[PyObject]) -> i64 {
    result = PyLong_AsLongLong(value);
    if result == -1 and failed() {
        raise boundary_failure();
    }
    return result;
}

def convert_ssize(value: ptr[PyObject]) -> i64 {
    index = PyNumber_Index(value);
    if not index {
        raise boundary_failure();
    }
    result = PyLong_AsSsize_t(index);
    jacpy_release(index);
    if result == -1 and failed() {
        raise boundary_failure();
    }
    return result;
}

# Py_ssize_t(accept={int, NoneType}): None keeps the C default.
def convert_optional_ssize(value: ptr[PyObject], fallback: i64) -> i64 {
    if jacpy_is_none(value) != 0 {
        return fallback;
    }
    if PyIndex_Check(value) == 0 {
        object_error(
            "TypeError", f"argument should be integer or None, not '{type_name(value)}'"
        );
        raise boundary_failure();
    }
    return convert_ssize(value);
}

def convert_unsigned_long(
    value: ptr[PyObject], bitwise: bool, fname: str, label: str
) -> u64 {
    if bitwise {
        if PyIndex_Check(value) == 0 {
            bad_argument(fname, label, "int", value);
        }
        return PyLong_AsUnsignedLongMask(value);
    }
    result = PyLong_AsUnsignedLong(value);
    if result == u64(0xFFFFFFFFFFFFFFFF) and failed() {
        raise boundary_failure();
    }
    return result;
}

def convert_unsigned_long_long(
    value: ptr[PyObject], bitwise: bool, fname: str, label: str
) -> u64 {
    if bitwise {
        if PyIndex_Check(value) == 0 {
            bad_argument(fname, label, "int", value);
        }
        return PyLong_AsUnsignedLongLongMask(value);
    }
    result = PyLong_AsUnsignedLongLong(value);
    if result == u64(0xFFFFFFFFFFFFFFFF) and failed() {
        raise boundary_failure();
    }
    return result;
}

# unsigned int / short / char: bitwise truncates, otherwise the range is checked.
def convert_unsigned_bounded(
    value: ptr[PyObject], bitwise: bool, limit: u64, kind: str, fname: str, label: str
) -> u64 {
    if bitwise {
        if PyIndex_Check(value) == 0 {
            bad_argument(fname, label, "int", value);
        }
        return PyLong_AsUnsignedLongMask(value) & limit;
    }
    wide = convert_long(value);
    if wide < 0 {
        object_error("OverflowError", f"{kind} is less than minimum");
        raise boundary_failure();
    }
    if u64(wide) > limit {
        object_error("OverflowError", f"{kind} is greater than maximum");
        raise boundary_failure();
    }
    return u64(wide);
}

def convert_double(value: ptr[PyObject]) -> f64 {
    result = PyFloat_AsDouble(value);
    if result == -1.0 and failed() {
        raise boundary_failure();
    }
    return result;
}

def convert_float(value: ptr[PyObject]) -> f32 {
    return f32(convert_double(value));
}

def convert_bool(value: ptr[PyObject]) -> bool {
    result = PyObject_IsTrue(value);
    if result < 0 {
        raise boundary_failure();
    }
    return result != 0;
}

# bool(accept={int}): the argument is read as a C int, so non-integers fail.
def convert_bool_int(value: ptr[PyObject]) -> bool {
    if jacpy_is_float(value) != 0 {
        object_error("TypeError", "integer argument expected, got float");
        raise boundary_failure();
    }
    return convert_int(value) != 0;
}

def convert_unicode(value: ptr[PyObject], fname: str, label: str) -> ptr[PyObject] {
    if jacpy_is_unicode(value) == 0 {
        bad_argument(fname, label, "str", value);
    }
    return value;
}

def convert_str(value: ptr[PyObject], fname: str, label: str) -> str {
    convert_unicode(value, fname, label);
    text = text_value(value);
    if "\x00" in text {
        object_error("ValueError", "embedded null character");
        raise boundary_failure();
    }
    return text;
}

# str(accept={str, NoneType}): None is passed through as the absent value.
def convert_optional_str(value: ptr[PyObject], fname: str, label: str) -> (str | None) {
    if jacpy_is_none(value) != 0 {
        return None;
    }
    return convert_str(value, fname, label);
}

def convert_buffer(value: ptr[PyObject], fname: str, label: str) -> BufferArgument {
    view = BufferArgument();
    if not view.acquire(value) {
        raise boundary_failure();
    }
    return view;
}

def convert_writable_buffer(
    value: ptr[PyObject], fname: str, label: str
) -> BufferArgument {
    view = BufferArgument();
    if not view.acquire_writable(value) {
        raise boundary_failure();
    }
    return view;
}

# Borrowed singletons, by CPython's Py_CONSTANT_* identifiers.
def borrowed_none -> ptr[PyObject] {
    return Py_GetConstantBorrowed(u32(0));
}

def borrowed_true -> ptr[PyObject] {
    return Py_GetConstantBorrowed(u32(2));
}

def borrowed_false -> ptr[PyObject] {
    return Py_GetConstantBorrowed(u32(1));
}

# A clinic class's defining-class token: the binding stores its type
# definition here once the type exists, and methods that take defining_class
# find it in the receiver's MRO by that token.
obj ClassToken {
    has handle: ptr = ptr();

    # Bindings set the token through this method: assigning the field of an
    # imported glob directly miscompiles in the native emitter (IntType has
    # no is_opaque), while a method of the object lowers correctly.
    def bind(handle: ptr) {
        self.handle = handle;
    }
}

def defining_class(receiver: ptr[PyObject], token: ClassToken) -> ptr[PyObject] {
    found = jacpy_binding_base(Py_TYPE(receiver), token.handle);
    if not found {
        raise boundary_failure();
    }
    return found;
}

# In a class method the receiver is the class, so the search starts there.
def defining_class_of_type(
    receiver: ptr[PyObject], token: ClassToken
) -> ptr[PyObject] {
    found = jacpy_binding_base(receiver, token.handle);
    if not found {
        raise boundary_failure();
    }
    return found;
}

def missing_argument(fname: str, name: str, position: int) {
    object_error(
        "TypeError", f"{fname}() missing required argument '{name}' (pos {position})"
    );
    raise boundary_failure();
}

# Return converters: a C sentinel with an exception set means failure.
def return_int(value: i32) -> ptr[PyObject] {
    return NULL if value == -1 and failed() else PyLong_FromLong(i64(value));
}

def return_bool(value: i32) -> ptr[PyObject] {
    return NULL if value == -1 and failed() else PyBool_FromLong(i64(value));
}

def return_long(value: i64) -> ptr[PyObject] {
    return NULL if value == -1 and failed() else PyLong_FromLong(value);
}

def return_ssize(value: i64) -> ptr[PyObject] {
    return NULL if value == -1 and failed() else PyLong_FromSsize_t(value);
}

def return_size(value: u64) -> ptr[PyObject] {
    return NULL
        if value == u64(0xFFFFFFFFFFFFFFFF) and failed()
        else PyLong_FromSize_t(value);
}

def return_unsigned(value: u32) -> ptr[PyObject] {
    return NULL
        if value == u32(0xFFFFFFFF) and failed()
        else PyLong_FromUnsignedLong(u64(value));
}

def return_double(value: f64) -> ptr[PyObject] {
    return NULL if value == -1.0 and failed() else PyFloat_FromDouble(value);
}
