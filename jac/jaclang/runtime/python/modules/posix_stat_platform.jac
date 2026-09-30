"""posix stat primitives for a target with no posix_stat_platform.<os>.jac; the binding rejects it."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.modules.stat_records { _Py_stat_struct }

glob PLATFORM: str = "",
     STATVFS_RECORD_SIZE: int = 8,
     STAT_EXTRA_FIELDS: list[tuple[str, str]] = [];

def stat_mode(st: _Py_stat_struct) -> i64 {
    return 0;
}

def stat_nlink(st: _Py_stat_struct) -> i64 {
    return 0;
}

def stat_blksize(st: _Py_stat_struct) -> i64 {
    return 0;
}

def stat_device(st: _Py_stat_struct) -> u64 {
    return 0;
}

def stat_rdev(st: _Py_stat_struct) -> u64 {
    return 0;
}

def set_stat_extra(v: ptr[PyObject], index: i64, st: _Py_stat_struct) -> bool {
    return True;
}

def statvfs_path(path: ptr[u8], record: ptr) -> i32 {
    return i32(-1);
}

def statvfs_fd(fd: i32, record: ptr) -> i32 {
    return i32(-1);
}

def statvfs_result(result_type: ptr[PyObject], record: ptr) -> ptr[PyObject] {
    return ptr[PyObject]();
}
