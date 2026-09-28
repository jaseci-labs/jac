"""Argument Clinic converters for native Jac bindings.

Each converter takes a borrowed argument and returns the C-level value that
CPython's generated clinic code would pass to the module's `_impl` function.
On failure the Python exception is set and boundary_failure is raised, which
the binding's invoke() turns into a NULL result. Messages follow
Python/getargs.c and Tools/clinic so upstream tests see the same text.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_is_float,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_unsigned_converter,
    NULL,
    Py_GetConstantBorrowed,
    Py_None,
    Py_TYPE,
    PyBool_FromLong,
    PyErr_Occurred,
    PyExc_OverflowError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyFloat_AsDouble,
    PyFloat_FromDouble,
    PyIndex_Check,
    PyLong_AsInt,
    PyLong_AsLong,
    PyLong_AsLongLong,
    PyLong_AsSsize_t,
    PyLong_AsUnsignedLongLongMask,
    PyLong_AsUnsignedLongMask,
    PyLong_FromLong,
    PyLong_FromSize_t,
    PyLong_FromSsize_t,
    PyLong_FromUnsignedLong,
    _PyLong_UInt16_Converter,
    _PyLong_UInt32_Converter,
    _PyLong_UnsignedInt_Converter,
    _PyLong_UnsignedShort_Converter,
    PyNumber_AsSsize_t,
    PyNumber_Index,
    PyObject,
    PyObject_AsFileDescriptor,
    PyObject_IsTrue
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_base,
    jacpy_binding_type_matches
}
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
    shown = "None" if value == Py_None else type_name(value);
    object_error(PyExc_TypeError, f"{fname}() {label} must be {expected}, not {shown}");
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

# Py_ssize_t(accept={int, NoneType}): _Py_convert_optional_to_ssize_t,
# where None keeps the C default and an index too large overflows with
# PyNumber_AsSsize_t's message.
def convert_optional_ssize(value: ptr[PyObject], fallback: i64) -> i64 {
    if value == Py_None {
        return fallback;
    }
    if PyIndex_Check(value) == 0 {
        object_error(
            PyExc_TypeError,
            f"argument should be integer or None, not '{type_name(value)}'"
        );
        raise boundary_failure();
    }
    result = PyNumber_AsSsize_t(value, PyExc_OverflowError);
    if result == -1 and failed() {
        raise boundary_failure();
    }
    return result;
}

def convert_unsigned_long(
    value: ptr[PyObject], bitwise: bool, fname: str, label: str
) -> u64 {
    if bitwise {
        if PyIndex_Check(value) == 0 {
            bad_argument(fname, label, "int", value);
        }
        masked = PyLong_AsUnsignedLongMask(value);
        if masked == u64(0xFFFFFFFFFFFFFFFF) and failed() {
            raise boundary_failure();
        }
        return masked;
    }
    result: u64 = 0;
    if jacpy_unsigned_converter(value, &mut result, 0) == 0 {
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
        masked = PyLong_AsUnsignedLongLongMask(value);
        if masked == u64(0xFFFFFFFFFFFFFFFF) and failed() {
            raise boundary_failure();
        }
        return masked;
    }
    result: u64 = 0;
    if jacpy_unsigned_converter(value, &mut result, 1) == 0 {
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
        object_error(PyExc_OverflowError, f"{kind} is less than minimum");
        raise boundary_failure();
    }
    if u64(wide) > limit {
        object_error(PyExc_OverflowError, f"{kind} is greater than maximum");
        raise boundary_failure();
    }
    return u64(wide);
}

# fildes: an int or an object with fileno(), as _PyLong_FileDescriptor_Converter.
def convert_fildes(value: ptr[PyObject], fname: str, label: str) -> i32 {
    fd = PyObject_AsFileDescriptor(value);
    if fd == -1 {
        raise boundary_failure();
    }
    return fd;
}

# The non-bitwise unsigned short, unsigned int, uint16 and uint32
# converters: CPython's _PyLong_*_Converter, which reject a negative value
# with ValueError and a wider one with OverflowError naming the C type.
def convert_unsigned_short(value: ptr[PyObject]) -> u16 {
    result: u16 = 0;
    if _PyLong_UnsignedShort_Converter(value, &mut result) == 0 {
        raise boundary_failure();
    }
    return result;
}

def convert_unsigned_int(value: ptr[PyObject]) -> u32 {
    result: u32 = 0;
    if _PyLong_UnsignedInt_Converter(value, &mut result) == 0 {
        raise boundary_failure();
    }
    return result;
}

def convert_uint16(value: ptr[PyObject]) -> u16 {
    result: u16 = 0;
    if _PyLong_UInt16_Converter(value, &mut result) == 0 {
        raise boundary_failure();
    }
    return result;
}

def convert_uint32(value: ptr[PyObject]) -> u32 {
    result: u32 = 0;
    if _PyLong_UInt32_Converter(value, &mut result) == 0 {
        raise boundary_failure();
    }
    return result;
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
        object_error(PyExc_TypeError, "integer argument expected, got float");
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
        object_error(PyExc_ValueError, "embedded null character");
        raise boundary_failure();
    }
    return text;
}

# str(accept={str, NoneType}): None is passed through as the absent value.
def convert_optional_str(value: ptr[PyObject], fname: str, label: str) -> (str | None) {
    if value == Py_None {
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
# find it in the receiver's MRO by that token. Several heap types can share
# one clinic class's methods (sha2's SHA224Type and SHA256Type); the binding
# binds the first and shares the others.
obj ClassToken {
    has handle: ptr = ptr(),
        shared: list[ptr] = [];

    def share(handle: ptr) {
        if handle not in self.shared {
            self.shared.append(handle);
        }
    }

    # The definition `cls` derives from; the bound one when none matches.
    def definition_of(cls: ptr[PyObject]) -> ptr {
        for handle in self.shared {
            if jacpy_binding_type_matches(cls, handle) != 0 {
                return handle;
            }
        }
        return self.handle;
    }
}

def defining_class(receiver: ptr[PyObject], token: ClassToken) -> ptr[PyObject] {
    cls = Py_TYPE(receiver);
    found = jacpy_binding_base(cls, token.definition_of(cls));
    if not found {
        raise boundary_failure();
    }
    return found;
}

# In a class method the receiver is the class, so the search starts there.
def defining_class_of_type(
    receiver: ptr[PyObject], token: ClassToken
) -> ptr[PyObject] {
    found = jacpy_binding_base(receiver, token.definition_of(receiver));
    if not found {
        raise boundary_failure();
    }
    return found;
}

def missing_argument(fname: str, name: str, position: int) {
    object_error(
        PyExc_TypeError,
        f"{fname}() missing required argument '{name}' (pos {position})"
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
