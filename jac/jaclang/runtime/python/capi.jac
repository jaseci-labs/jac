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
    PyUnicode_DecodeUTF8Stateful,
    jacpy_unicode_intern_text,
    jacpy_bytes_copy_to,
    jacpy_bytes_from_memory,
    jacpy_bytes_from_payload,
    jacpy_bytes_length,
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
    PyBytes_Type,
    PyDict_GetItemRef,
    PyDict_SetItem,
    PyDict_Type,
    PyErr_GetRaisedException,
    PyErr_SetRaisedException,
    PyFloat_Type,
    PyFrozenSet_Type,
    PyFunction_Type,
    PyList_Type,
    PyLong_Type,
    PyMem_RawMalloc,
    _PyNone_Type,
    PyObject,
    PyObject_Repr,
    PyPickleBuffer_Type,
    PySet_Type,
    jacpy_audit_tuple_text,
    PyTuple_New,
    PyTuple_Type,
    PyType_Type,
    PyUnicode_Type,
    PyUnicodeWriter,
    PyObject_CallMethod
}
import from c {
    def jac_heap_size(address: u64) -> i64;  def jac_list_heap_size(
        address: u64
    ) -> i64;
}

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

def builtin_kind_of(value: ptr[PyObject]) -> int;

def builtin_type(kind: builtin_kind) -> ptr[PyObject];

def object_error(kind: ptr[PyObject], message: str);

def c_int(value: int) -> i32;

def c_size(value: i64) -> u64;

def memory_byte(address: ptr, offset: i64) -> i64;

def memory_set(address: ptr, offset: i64, value: i64);

def read_buffer(handle: ptr[PyObject]) -> bytes;

def write_buffer(data: bytes) -> ptr[PyObject];

obj module_failure(Exception) {
    has message: str;
}

obj boundary_failure(Exception) {}

def raise_boundary_failure;

def required(handle: ptr[PyObject]) -> ptr[PyObject];

def text_object(value: str) -> ptr[PyObject];

def text_value(value: ptr[PyObject]) -> str;

def repr_value(value: ptr[PyObject]) -> str;

def pair(first: ptr[PyObject], second: ptr[PyObject]) -> ptr[PyObject];

def checked(status: i64);

def object_tuple(values: list[ptr[PyObject]]) -> ptr[PyObject];

def audit_event(event: str, values: list[ptr[PyObject]]) -> bool;

def type_name(value: ptr[PyObject], qualified: bool = False) -> str;

def serialization_note(
    value: ptr[PyObject], key: ptr[PyObject], index: int, kind: int, detail: str = ""
);

def dict_set_text(dict_: ptr[PyObject], key: str, value: ptr[PyObject]) -> i32;

def dict_get_text(dict_: ptr[PyObject], key: str) -> tuple[i32, ptr[PyObject]];

def new_writer -> ptr[PyUnicodeWriter];

def c_string_length(address: ptr[u8], limit: int = -1) -> int;

def c_string_text(address: ptr[u8], limit: int = -1) -> ptr[PyObject];

def c_text(address: ptr, size: i64) -> ptr[PyObject];

def c_string_copy(text: str) -> ptr[u8];

obj StaticText {
    has text: str,
        address: ptr[u8] = ptr[u8]();

    def get -> ptr[u8];
}

impl builtin_kind_of(value: ptr[PyObject]) -> int {
    exact = Py_TYPE(value);
    for kind in range(len(BUILTIN_TYPES)) {
        if BUILTIN_TYPES[kind] == exact {
            return kind;
        }
    }
    return builtin_kind.OTHER.value;
}

impl builtin_type(kind: builtin_kind) -> ptr[PyObject] {
    return Py_NewRef(BUILTIN_TYPES[kind.value]);
}

impl object_error(kind: ptr[PyObject], message: str) {
    jacpy_set_exception(kind, message, i64(len(message.encode("utf-8"))));
}

impl c_int(value: int) -> i32 {
    bits = value & 0xFFFFFFFF;
    if bits >= 0x80000000 {
        bits -= 0x100000000;
    }
    return i32(bits);
}

impl c_size(value: i64) -> u64 {
    if value >= 0 {
        return u64(value);
    }
    return ~u64(-(value + 1));
}

impl memory_byte(address: ptr, offset: i64) -> i64 {
    return i64(ptr[u8](int(address) + int(offset)).view(1)[0]);
}

impl memory_set(address: ptr, offset: i64, value: i64) {
    ptr[u8](int(address) + int(offset)).view(1)[0] = u8(value & 255);
}

impl read_buffer(handle: ptr[PyObject]) -> bytes {
    size = jacpy_bytes_length(handle);
    data = b"\x00" * int(size);
    jacpy_bytes_copy_to(handle, data, size);
    return data;
}

impl write_buffer(data: bytes) -> ptr[PyObject] {
    return jacpy_bytes_from_payload(data, i64(len(data)));
}

impl raise_boundary_failure {
    raise boundary_failure();
}

impl required(handle: ptr[PyObject]) -> ptr[PyObject] {
    if handle == 0 {
        raise_boundary_failure();
    }
    return handle;
}

impl text_object(value: str) -> ptr[PyObject] {
    return required(
        jacpy_text(value, i64(len(value.encode("utf-8", "surrogatepass"))))
    );
}

impl text_value(value: ptr[PyObject]) -> str {
    buffer = required(jacpy_utf8(value));
    try {
        return read_buffer(buffer).decode("utf-8", "surrogatepass");
    } finally {
        jacpy_release(buffer);
    }
}

impl repr_value(value: ptr[PyObject]) -> str {
    result = required(PyObject_Repr(value));
    try {
        return text_value(result);
    } finally {
        jacpy_release(result);
    }
}

impl pair(first: ptr[PyObject], second: ptr[PyObject]) -> ptr[PyObject] {
    result = required(PyTuple_New(2));
    jacpy_tuple_set_owned(result, 0, Py_NewRef(first));
    jacpy_tuple_set_owned(result, 1, Py_NewRef(second));
    return result;
}

impl checked(status: i64) {
    if status < 0 {
        raise_boundary_failure();
    }
}

impl object_tuple(values: list[ptr[PyObject]]) -> ptr[PyObject] {
    result = required(PyTuple_New(i64(len(values))));
    for i in range(len(values)) {
        jacpy_tuple_set_owned(result, i64(i), Py_NewRef(values[i]));
    }
    return result;
}

impl audit_event(event: str, values: list[ptr[PyObject]]) -> bool {
    complete = True;
    for value in values {
        if not value {
            complete = False;
        }
    }
    status = i32(-1);
    if complete {
        arguments = PyTuple_New(i64(len(values)));
        if arguments {
            for i in range(len(values)) {
                jacpy_tuple_set_owned(arguments, i64(i), Py_NewRef(values[i]));
            }
            status = jacpy_audit_tuple_text(event, arguments);
            jacpy_release(arguments);
        }
    }
    for value in values {
        jacpy_release(value);
    }
    return status >= 0;
}

impl type_name(value: ptr[PyObject], qualified: bool = False) -> str {
    name = required(
        jacpy_qualified_type_name(value) if qualified else jacpy_type_name(value)
    );
    try {
        return text_value(name);
    } finally {
        jacpy_release(name);
    }
}

impl serialization_note(
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
            added = PyObject_CallMethod(error, "add_note", "O", note);
            checked(i64(0 if added else -1));
            jacpy_release(added);
        } finally {
            jacpy_release(note);
        }
    } except boundary_failure {} finally {
        PyErr_SetRaisedException(error);
    }
}

impl dict_set_text(dict_: ptr[PyObject], key: str, value: ptr[PyObject]) -> i32 {
    key_object = jacpy_unicode_intern_text(key);
    if not key_object {
        return i32(-1);
    }
    status = PyDict_SetItem(dict_, key_object, value);
    jacpy_release(key_object);
    return status;
}

impl dict_get_text(dict_: ptr[PyObject], key: str) -> tuple[i32, ptr[PyObject]] {
    value: ptr[PyObject] = ptr[PyObject]();
    key_object = jacpy_unicode_intern_text(key);
    if not key_object {
        return (i32(-1), value);
    }
    status = PyDict_GetItemRef(dict_, key_object, &mut value);
    jacpy_release(key_object);
    return (status, value);
}

impl new_writer -> ptr[PyUnicodeWriter] {
    writer = jacpy_writer_new();
    if not writer {
        raise boundary_failure();
    }
    return writer;
}

impl c_string_length(address: ptr[u8], limit: int = -1) -> int {
    length = 0;
    while limit < 0 or length < limit {
        if (address + length).view(1)[0] == 0 {
            break;
        }
        length += 1;
    }
    return length;
}

impl c_string_text(address: ptr[u8], limit: int = -1) -> ptr[PyObject] {
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

impl c_text(address: ptr, size: i64) -> ptr[PyObject] {
    return PyUnicode_DecodeUTF8Stateful(address, size, ptr[u8](), None);
}

impl c_string_copy(text: str) -> ptr[u8] {
    encoded = text.encode("utf-8");
    size = len(encoded);
    memory = ptr[u8](PyMem_RawMalloc(u64(size + 1)));
    if memory.is_null() {
        return memory;
    }
    characters = memory.view(size + 1);
    for i in range(size) {
        characters[i] = u8(encoded[i]);
    }
    characters[size] = u8(0);
    return memory;
}

impl StaticText.get -> ptr[u8] {
    if not self.address {
        self.address = c_string_copy(self.text);
    }
    return self.address;
}
