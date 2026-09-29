"""C fields published as attributes with CPython's structmember conversions.

A native object keeps the C record behind an attribute in memory it owns;
reads and writes go through PyMember_GetOne()/PyMember_SetOne() on that
address, so range checks, truncation warnings and messages are CPython's own.
"""

import from jaclang.runtime.python.cpython_api {
    PyMember_GetOne,
    PyMember_SetOne,
    PyMemberDef,
    PyObject
}

# Py_T_* field types (Include/descrobject.h) and the Py_READONLY flag.
enum MemberType {
    SHORT = 0,
    INT = 1,
    LONG = 2,
    FLOAT = 3,
    DOUBLE = 4,
    STRING = 5,
    OBJECT = 6,
    CHAR = 7,
    BYTE = 8,
    UBYTE = 9,
    USHORT = 10,
    UINT = 11,
    ULONG = 12,
    BOOL = 14,
    OBJECT_EX = 16,
    LONGLONG = 17,
    ULONGLONG = 18,
    PYSSIZET = 19
}

glob READONLY: i32 = 1;

# One field: the attribute name, its Py_T_* type and byte offset in the
# record, and its docstring (None is C's NULL doc).
obj MemberField {
    has name: str,
        kind: int,
        offset: int,
        readonly: bool = False,
        doc: (str | None) = None;

    def record -> PyMemberDef {
        return PyMemberDef(
            type_=i32(self.kind),
            offset=i64(self.offset),
            flags=READONLY if self.readonly else i32(0)
        );
    }

    # The field of the record at `address` as a new Python object.
    def read(address: ptr) -> ptr[PyObject] {
        definition = self.record();
        return PyMember_GetOne(address, &definition);
    }

    # Store `value` (NULL deletes, which numeric fields refuse) into the
    # record at `address`; -1 with the exception set on failure.
    def write(address: ptr, value: ptr[PyObject]) -> i32 {
        definition = self.record();
        return PyMember_SetOne(address, &definition, value);
    }
}

# A field record whose object fields mirror references a native state owns:
# the record holds them borrowed, so a type zeroes it (record_clear) before its
# state releases them.
def record_set_object(record: ptr, offset: int, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](int(record) + offset).view(1)[0] = value;
}

# The object field at `offset`, borrowed (NULL when unset).
def record_object(record: ptr, offset: int) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](int(record) + offset).view(1)[0];
}

# A C int field at `offset`.
def record_int(record: ptr, offset: int) -> i32 {
    return ptr[i32](int(record) + offset).view(1)[0];
}

def record_set_int(record: ptr, offset: int, value: int) {
    ptr[i32](int(record) + offset).view(1)[0] = i32(value);
}

def record_set_byte(record: ptr, offset: int, value: int) {
    ptr[i8](int(record) + offset).view(1)[0] = i8(value);
}

def record_clear(record: ptr, size: int) {
    if int(record) == 0 {
        return;
    }
    bytes = ptr[u8](record).view(size);
    for index in range(size) {
        bytes[index] = u8(0);
    }
}
