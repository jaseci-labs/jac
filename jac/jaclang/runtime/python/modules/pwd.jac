"""The Unix password database.

Derived from CPython 3.14.6 Modules/pwdmodule.c; see ../LICENSE.cpython.
Lookups use the reentrant C library calls with the GIL released and a buffer
that doubles on ERANGE, as the C module does.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_AsString,
    PyErr_NoMemory,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyList_Append,
    PyList_New,
    PyLong_FromLong,
    PyMem_RawFree,
    PyMem_RawRealloc,
    PyObject,
    PySequence_Contains,
    PyStructSequence_New,
    PyStructSequence_SetItem,
    PyThreadState,
    PyUnicode_EncodeFSDefault,
    PyUnicode_FromString,
    jacpy_error_is,
    jacpy_fs_text,
    jacpy_release
}
import from jaclang.runtime.python.capi { object_error, repr_value }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.modules.user_records { passwd, SC_GETPW_R_SIZE_MAX }
import from c {
    def getpwuid_r(
        uid: u32, record: &mut passwd, buffer: ptr, size: u64, result: &mut ptr[passwd]
    ) -> i32;  def getpwnam_r(
        name: ptr[u8],
        record: &mut passwd,
        buffer: ptr,
        size: u64,
        result: &mut ptr[passwd]
    ) -> i32;  def setpwent;  def getpwent -> ptr[passwd];  def endpwent;  def sysconf(
        name: i32
    ) -> i64;  def _Py_Uid_Converter(value: ptr[PyObject], uid: &mut u32) -> i32;  def _PyLong_FromUid(
        uid: u32
    ) -> ptr[PyObject];
}

glob:priv ERANGE: i32 = 34,
     DEFAULT_BUFFER_SIZE: i64 = 1024,
     SSIZE_MAX: i64 = 0x7FFFFFFFFFFFFFFF;

# Each item is a new reference the sequence takes over; NULL fails the row.
def:priv mkpwent(module: ptr[PyObject], record: passwd) -> ptr[PyObject] {
    row = PyStructSequence_New(jacpy_binding_state_get(module, 0));
    if not row {
        return NULL;
    }
    items = [
        jacpy_fs_text(record.pw_name),
        jacpy_fs_text(record.pw_passwd),
        _PyLong_FromUid(record.pw_uid),
        _PyLong_FromUid(record.pw_gid),
        jacpy_fs_text(record.pw_gecos),
        jacpy_fs_text(record.pw_dir),
        jacpy_fs_text(record.pw_shell)
    ];
    failed = False;
    for index in range(len(items)) {
        if not items[index] {
            failed = True;
        } else {
            PyStructSequence_SetItem(row, i64(index), items[index]);
        }
    }
    if failed {
        jacpy_release(row);
        return NULL;
    }
    return row;
}

# Run one reentrant lookup, growing the buffer on ERANGE with the GIL released.
# Returns the found flag, whether memory ran out, and the buffer to free.
def:priv lookup(
    by_name: bool, uid: u32, name: ptr[u8], record: &mut passwd
) -> tuple[bool, bool, ptr] {
    size = sysconf(SC_GETPW_R_SIZE_MAX);
    if size == -1 {
        size = DEFAULT_BUFFER_SIZE;
    }
    buffer = ptr();
    found = False;
    nomem = False;
    state = PyEval_SaveThread();
    while True {
        grown = PyMem_RawRealloc(buffer, u64(size));
        if not grown {
            nomem = True;
            break;
        }
        buffer = grown;
        result = ptr[passwd]();
        status = getpwnam_r(name, record, buffer, u64(size), &mut result)
            if by_name
            else getpwuid_r(uid, record, buffer, u64(size), &mut result);
        found = status == 0 and bool(result);
        if found or status != ERANGE {
            break;
        }
        if size > (SSIZE_MAX >> 1) {
            nomem = True;
            break;
        }
        size = size << 1;
    }
    PyEval_RestoreThread(state);
    return (found, nomem, buffer);
}

def pwd_getpwuid_impl(module: ptr[PyObject], uidobj: ptr[PyObject]) -> ptr[PyObject] {
    uid = u32(0);
    if _Py_Uid_Converter(uidobj, &mut uid) == 0 {
        if jacpy_error_is("OverflowError") != 0 {
            object_error("KeyError", "getpwuid(): uid not found");
        }
        return NULL;
    }
    record = passwd();
    (found, nomem, buffer) = lookup(False, uid, ptr[u8](), &mut record);
    result = NULL;
    if found {
        result = mkpwent(module, record);
    } elif nomem {
        PyErr_NoMemory();
    } else {
        number = _PyLong_FromUid(uid);
        if number {
            object_error(
                "KeyError", f"getpwuid(): uid not found: {repr_value(number)}"
            );
            jacpy_release(number);
        }
    }
    PyMem_RawFree(buffer);
    return result;
}

# PyBytes_AsStringAndSize(name, &chars, NULL) rejects an embedded null byte.
def without_null(encoded: ptr[PyObject]) -> bool {
    zero = PyLong_FromLong(0);
    if not zero {
        return False;
    }
    found = PySequence_Contains(encoded, zero);
    jacpy_release(zero);
    if found > 0 {
        object_error("ValueError", "embedded null byte");
    }
    return found == 0;
}

def pwd_getpwnam_impl(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    encoded = PyUnicode_EncodeFSDefault(name);
    if not encoded {
        return NULL;
    }
    if not without_null(encoded) {
        jacpy_release(encoded);
        return NULL;
    }
    text = PyBytes_AsString(encoded);
    result = NULL;
    if text {
        record = passwd();
        (found, nomem, buffer) = lookup(True, u32(0), text, &mut record);
        if found {
            result = mkpwent(module, record);
        } elif nomem {
            PyErr_NoMemory();
        } else {
            object_error("KeyError", f"getpwnam(): name not found: {repr_value(name)}");
        }
        PyMem_RawFree(buffer);
    }
    jacpy_release(encoded);
    return result;
}

def pwd_getpwall_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    entries = PyList_New(0);
    if not entries {
        return NULL;
    }
    setpwent();
    while True {
        record = getpwent();
        if record.is_null() {
            break;
        }
        row = mkpwent(module, record.view(1)[0]);
        if not row or PyList_Append(entries, row) != 0 {
            jacpy_release(row);
            jacpy_release(entries);
            endpwent();
            return NULL;
        }
        jacpy_release(row);
    }
    endpwent();
    return entries;
}
