"""The Unix group database.

Derived from CPython 3.14.6 Modules/grpmodule.c; see ../LICENSE.cpython.
struct group has the same layout on every supported C library.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_AsString,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyList_Append,
    PyList_New,
    PyMem_RawFree,
    PyMem_RawRealloc,
    PyObject,
    PyStructSequence_New,
    PyStructSequence_SetItem,
    PyUnicode_EncodeFSDefault,
    jacpy_fs_text,
    jacpy_release
}
import from jaclang.runtime.python.capi { object_error, repr_value }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.modules.user_records { SC_GETGR_R_SIZE_MAX }
import from c {
    obj group {
        has gr_name: ptr[u8] = ptr[u8](),
            gr_passwd: ptr[u8] = ptr[u8](),
            gr_gid: u32 = 0,
            gr_mem: ptr[ptr[u8]] = ptr[ptr[u8]]();
    }  def getgrgid_r(
        gid: u32, record: &mut group, buffer: ptr, size: u64, result: &mut ptr[group]
    ) -> i32;  def getgrnam_r(
        name: ptr[u8],
        record: &mut group,
        buffer: ptr,
        size: u64,
        result: &mut ptr[group]
    ) -> i32;  def setgrent;  def getgrent -> ptr[group];  def endgrent;  def sysconf(
        name: i32
    ) -> i64;  def _Py_Gid_Converter(value: ptr[PyObject], gid: &mut u32) -> i32;  def _PyLong_FromGid(
        gid: u32
    ) -> ptr[PyObject];
}

glob:priv ERANGE: i32 = 34,
     DEFAULT_BUFFER_SIZE: i64 = 1024,
     SSIZE_MAX: i64 = 0x7FFFFFFFFFFFFFFF;

def:priv members(record: group) -> ptr[PyObject] {
    names = PyList_New(0);
    if not names or record.gr_mem.is_null() {
        return names;
    }
    index = 0;
    while True {
        member = record.gr_mem.view(index + 1)[index];
        if member.is_null() {
            return names;
        }
        text = jacpy_fs_text(member);
        if not text or PyList_Append(names, text) != 0 {
            jacpy_release(text);
            jacpy_release(names);
            return NULL;
        }
        jacpy_release(text);
        index += 1;
    }
}

def:priv mkgrent(module: ptr[PyObject], record: group) -> ptr[PyObject] {
    row = PyStructSequence_New(jacpy_binding_state_get(module, 0));
    if not row {
        return NULL;
    }
    items = [
        jacpy_fs_text(record.gr_name),
        jacpy_fs_text(record.gr_passwd),
        _PyLong_FromGid(record.gr_gid),
        members(record)
    ];
    failed = False;
    for index in range(len(items)) {
        if not items[index] {
            failed = True;
        } else {
            PyStructSequence_SetItem(row, i64(index), items[index]);
        }
    }
    if failed or PyErr_Occurred() {
        jacpy_release(row);
        return NULL;
    }
    return row;
}

def:priv lookup(
    by_name: bool, gid: u32, name: ptr[u8], record: &mut group
) -> tuple[bool, bool, ptr] {
    size = sysconf(SC_GETGR_R_SIZE_MAX);
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
        result = ptr[group]();
        status = getgrnam_r(name, record, buffer, u64(size), &mut result)
            if by_name
            else getgrgid_r(gid, record, buffer, u64(size), &mut result);
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

def grp_getgrgid_impl(module: ptr[PyObject], id_: ptr[PyObject]) -> ptr[PyObject] {
    gid = u32(0);
    if _Py_Gid_Converter(id_, &mut gid) == 0 {
        return NULL;
    }
    record = group();
    (found, nomem, buffer) = lookup(False, gid, ptr[u8](), &mut record);
    result = NULL;
    if found {
        result = mkgrent(module, record);
    } elif nomem {
        PyErr_NoMemory();
    } else {
        number = _PyLong_FromGid(gid);
        if number {
            object_error(
                "KeyError", f"getgrgid(): gid not found: {repr_value(number)}"
            );
            jacpy_release(number);
        }
    }
    PyMem_RawFree(buffer);
    return result;
}

def grp_getgrnam_impl(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    encoded = PyUnicode_EncodeFSDefault(name);
    if not encoded {
        return NULL;
    }
    text = PyBytes_AsString(encoded);
    result = NULL;
    if text {
        record = group();
        (found, nomem, buffer) = lookup(True, u32(0), text, &mut record);
        if found {
            result = mkgrent(module, record);
        } elif nomem {
            PyErr_NoMemory();
        } else {
            object_error("KeyError", f"getgrnam(): name not found: {repr_value(name)}");
        }
        PyMem_RawFree(buffer);
    }
    jacpy_release(encoded);
    return result;
}

def grp_getgrall_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    rows = PyList_New(0);
    if not rows {
        return NULL;
    }
    setgrent();
    while True {
        record = getgrent();
        if record.is_null() {
            break;
        }
        row = mkgrent(module, record.view(1)[0]);
        if not row or PyList_Append(rows, row) != 0 {
            jacpy_release(row);
            jacpy_release(rows);
            endgrent();
            return NULL;
        }
        jacpy_release(row);
    }
    endgrent();
    return rows;
}
