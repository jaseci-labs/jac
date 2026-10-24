"""The system UUID generator.

Derived from CPython 3.14.6 Modules/_uuidmodule.c; see ../LICENSE.cpython.
The C library interface is uuid_library.<os>.jac: whether the target has
<uuid/uuid.h>, uuid_generate_time_safe() and a stable MAC address source.
"""

glob UUID_SIZE: i64 = 16;

# generate_time_safe() -> (bytes, status): the status is None where the
# library has only uuid_generate_time().
def py_uuid_generate_time_safe(
    context: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    uuid = jacpy_buffer_new(UUID_SIZE);
    if not uuid {
        return NULL;
    }
    status = generate_time(PyBytes_AsString(uuid));
    return owned_tuple(
        [
            uuid,
            PyLong_FromLong(i64(status))
                if HAVE_GENERATE_TIME_SAFE
                else Py_NewRef(borrowed_none())
        ]
    );
}
