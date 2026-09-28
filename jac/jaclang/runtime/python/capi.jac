"""Retained CPython object operations for native Jac module implementations.

Handles borrow their arguments. Object-producing operations return a new
reference (zero on error), released with jacpy_release or returned to Python.
All calls require the interpreter lock; exceptions remain in CPython's thread
state. No Python implementation of a replaced module is invoked here.
"""
enum builtin_kind {
    NONE = 0,
    BOOL = 1,
    INT = 2,
    FLOAT = 3,
    BYTES = 4,
    STR = 5,
    TUPLE = 6,
    LIST = 7,
    DICT = 8,
    SET = 9,
    FROZENSET = 10,
    BYTEARRAY = 11,
    TYPE = 12,
    FUNCTION = 13,
    PICKLE_BUFFER = 14,
    OTHER = 15
}

import from jaclang.runtime.python.cpython_api {
    jacpy_bytes_copy_to,
    jacpy_bytes_from_memory,
    jacpy_bytes_length,
    jacpy_exception_note,
    jacpy_qualified_type_name,
    jacpy_release,
    jacpy_set_exception,
    jacpy_text,
    jacpy_tuple_set_owned,
    jacpy_type_name,
    jacpy_unicode_decode_bytes,
    jacpy_utf8,
    jacpy_writer_new,
    Py_NewRef,
    Py_TYPE,
    PyBool_Type,
    PyByteArray_Type,
    PyBytes_FromStringAndSize,
    PyBytes_Type,
    PyDict_Type,
    PyErr_GetRaisedException,
    PyErr_SetRaisedException,
    PyFloat_Type,
    PyFrozenSet_Type,
    PyFunction_Type,
    PyList_Type,
    PyLong_Type,
    _PyNone_Type,
    PyObject,
    PyObject_Repr,
    PyPickleBuffer_Type,
    PySet_Type,
    PyTuple_New,
    PyTuple_Type,
    PyType_Type,
    PyUnicode_Type,
    PyUnicodeWriter
}
import from c {
    def jac_heap_size(address: u64) -> i64;  def jac_list_heap_size(
        address: u64
    ) -> i64;
}

# The exact type of each builtin_kind, in value order; NONE is NoneType.
glob:priv BUILTIN_TYPES: list[ptr[PyObject]] = [
         addressof(_PyNone_Type),
         addressof(PyBool_Type),
         addressof(PyLong_Type),
         addressof(PyFloat_Type),
         addressof(PyBytes_Type),
         addressof(PyUnicode_Type),
         addressof(PyTuple_Type),
         addressof(PyList_Type),
         addressof(PyDict_Type),
         addressof(PySet_Type),
         addressof(PyFrozenSet_Type),
         addressof(PyByteArray_Type),
         addressof(PyType_Type),
         addressof(PyFunction_Type),
         addressof(PyPickleBuffer_Type)
     ];

"""The builtin_kind value of a value's exact type; OTHER for a subclass or any
other type."""
def builtin_kind_of(value: ptr[PyObject]) -> int {
    exact = Py_TYPE(value);
    for kind in range(len(BUILTIN_TYPES)) {
        if BUILTIN_TYPES[kind] == exact {
            return kind;
        }
    }
    return builtin_kind.OTHER.value;
}

"""The exact type of a builtin_kind other than OTHER, as a new reference."""
def builtin_type(kind: builtin_kind) -> ptr[PyObject] {
    return Py_NewRef(BUILTIN_TYPES[kind.value]);
}

# Raise `kind` (an exception type such as PyExc_ValueError) with a text message.
def object_error(kind: ptr[PyObject], message: str) {
    jacpy_set_exception(kind, message, i64(len(message.encode("utf-8"))));
}

# The byte at `address + offset` of C memory.
def memory_byte(address: ptr, offset: i64) -> i64 {
    return i64(ptr[u8](int(address) + int(offset)).view(1)[0]);
}

# Store the low byte of `value` at `address + offset` of C memory.
def memory_set(address: ptr, offset: i64, value: i64) {
    ptr[u8](int(address) + int(offset)).view(1)[0] = u8(value & 255);
}

# The payload of a retained bytes-like value, copied into Jac storage.
def read_buffer(handle: ptr[PyObject]) -> bytes {
    size = jacpy_bytes_length(handle);
    data = b"\x00" * int(size);
    jacpy_bytes_copy_to(handle, data, size);
    return data;
}

def write_buffer(data: bytes) -> ptr[PyObject] {
    return PyBytes_FromStringAndSize(data, i64(len(data)));
}

obj module_failure(Exception) {
    has message: str;
}

obj boundary_failure(Exception) {}

def required(handle: ptr[PyObject]) -> ptr[PyObject] {
    if handle == 0 {
        raise boundary_failure();
    }
    return handle;
}

def text_object(value: str) -> ptr[PyObject] {
    return required(
        jacpy_text(value, i64(len(value.encode("utf-8", "surrogatepass"))))
    );
}

def text_value(value: ptr[PyObject]) -> str {
    buffer = required(jacpy_utf8(value));
    try {
        return read_buffer(buffer).decode("utf-8", "surrogatepass");
    } finally {
        jacpy_release(buffer);
    }
}

def repr_value(value: ptr[PyObject]) -> str {
    result = required(PyObject_Repr(value));
    try {
        return text_value(result);
    } finally {
        jacpy_release(result);
    }
}

# Both inputs are borrowed; the returned tuple owns its references.
def pair(first: ptr[PyObject], second: ptr[PyObject]) -> ptr[PyObject] {
    result = required(PyTuple_New(2));
    jacpy_tuple_set_owned(result, 0, Py_NewRef(first));
    jacpy_tuple_set_owned(result, 1, Py_NewRef(second));
    return result;
}

def checked(status: i64) {
    if status < 0 {
        raise boundary_failure();
    }
}

# Entries are borrowed; each successful result owns all its element references.
def object_tuple(values: list[ptr[PyObject]]) -> ptr[PyObject] {
    result = required(PyTuple_New(i64(len(values))));
    for i in range(len(values)) {
        jacpy_tuple_set_owned(result, i64(i), Py_NewRef(values[i]));
    }
    return result;
}

def type_name(value: ptr[PyObject], qualified: bool = False) -> str {
    name = required(
        jacpy_qualified_type_name(value) if qualified else jacpy_type_name(value)
    );
    try {
        return text_value(name);
    } finally {
        jacpy_release(name);
    }
}

# Preserve the original exception if formatting a diagnostic invokes user code.
def serialization_note(
    value: ptr[PyObject], key: ptr[PyObject], index: int, kind: int, detail: str = ""
) {
    error = PyErr_GetRaisedException();
    if error == 0 {
        return;
    }
    try {
        tail = " " + detail if detail else " object";
        if kind == 1 {
            tail = " item " + str(index);
        } elif kind == 2 {
            tail = " item " + repr_value(key);
        }
        note = text_object("when serializing " + type_name(value, True) + tail);
        try {
            checked(jacpy_exception_note(error, note));
        } finally {
            jacpy_release(note);
        }
    } except boundary_failure {} finally {
        PyErr_SetRaisedException(error);
    }
}

# A fresh PyUnicodeWriter, or boundary_failure with the error set.
def new_writer -> ptr[PyUnicodeWriter] {
    writer = jacpy_writer_new();
    if not writer {
        raise boundary_failure();
    }
    return writer;
}

# The length of a NUL-terminated C string, reading at most `limit` bytes
# when `limit` is not negative (strnlen()).
def c_string_length(address: ptr[u8], limit: int = -1) -> int {
    length = 0;
    while limit < 0 or length < limit {
        if (address + length).view(1)[0] == 0 {
            break;
        }
        length += 1;
    }
    return length;
}

# A C string as a new str decoded as strict UTF-8, as PyUnicode_FromString()
# does; `limit` caps the bytes read, as strncpy() into a fixed buffer would.
def c_string_text(address: ptr[u8], limit: int = -1) -> ptr[PyObject] {
    payload = jacpy_bytes_from_memory(
        ptr(address), i64(c_string_length(address, limit))
    );
    if not payload {
        return payload;
    }
    text = jacpy_unicode_decode_bytes(payload, "utf-8");
    jacpy_release(payload);
    return text;
}
