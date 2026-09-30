"""The Linux side of the posix stat area: struct stat's field widths and
struct statvfs, as the C library lays it out on x86_64 and aarch64.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    PyLong_FromLong,
    PyLong_FromLongLong,
    PyLong_FromUnsignedLong,
    PyObject,
    jacpy_release
}
import from jaclang.runtime.python.object_model.structseq {
    PyStructSequence_New,
    PyStructSequence_SetItem
}
import from jaclang.runtime.python.modules.stat_records { _Py_stat_struct }
import from c {
    obj statvfs_record {
        has f_bsize: u64 = 0,
            f_frsize: u64 = 0,
            f_blocks: u64 = 0,
            f_bfree: u64 = 0,
            f_bavail: u64 = 0,
            f_files: u64 = 0,
            f_ffree: u64 = 0,
            f_favail: u64 = 0,
            f_fsid: u64 = 0,
            f_flag: u64 = 0,
            f_namemax: u64 = 0,
            f_spare_0: i32 = 0,
            f_spare_1: i32 = 0,
            f_spare_2: i32 = 0,
            f_spare_3: i32 = 0,
            f_spare_4: i32 = 0,
            f_spare_5: i32 = 0;
    }  def statvfs(path: ptr[u8], buffer: ptr) -> i32;  def fstatvfs(
        fd: i32, buffer: ptr
    ) -> i32;
}

glob PLATFORM: str = "linux",
     STATVFS_RECORD_SIZE: int = 112,
     STAT_EXTRA_FIELDS: list[tuple[str, str]] = [];

def stat_mode(st: _Py_stat_struct) -> i64 {
    return i64(st.st_mode);
}

def stat_nlink(st: _Py_stat_struct) -> i64 {
    return i64.wrap(st.st_nlink);
}

def stat_blksize(st: _Py_stat_struct) -> i64 {
    return i64(st.st_blksize);
}

def stat_device(st: _Py_stat_struct) -> u64 {
    return st.st_dev;
}

def stat_rdev(st: _Py_stat_struct) -> u64 {
    return st.st_rdev;
}

def set_stat_extra(v: ptr[PyObject], index: i64, st: _Py_stat_struct) -> bool {
    return True;
}

def statvfs_path(path: ptr[u8], record: ptr) -> i32 {
    return statvfs(path, record);
}

def statvfs_fd(fd: i32, record: ptr) -> i32 {
    return fstatvfs(fd, record);
}

# _pystatvfs_fromstructstatvfs(), 64-bit (HAVE_LARGEFILE_SUPPORT undefined).
def statvfs_result(result_type: ptr[PyObject], record: ptr) -> ptr[PyObject] {
    v = PyStructSequence_New(result_type);
    if not v {
        return v;
    }
    st = ptr[statvfs_record](record).view(1)[0];
    items = [
        PyLong_FromLong(i64.wrap(st.f_bsize)),
        PyLong_FromLong(i64.wrap(st.f_frsize)),
        PyLong_FromLong(i64.wrap(st.f_blocks)),
        PyLong_FromLong(i64.wrap(st.f_bfree)),
        PyLong_FromLong(i64.wrap(st.f_bavail)),
        PyLong_FromLong(i64.wrap(st.f_files)),
        PyLong_FromLong(i64.wrap(st.f_ffree)),
        PyLong_FromLong(i64.wrap(st.f_favail)),
        PyLong_FromLong(i64.wrap(st.f_flag)),
        PyLong_FromLong(i64.wrap(st.f_namemax)),
        PyLong_FromUnsignedLong(st.f_fsid)
    ];
    for index in range(len(items)) {
        if not items[index] {
            for rest in range(index + 1, len(items)) {
                jacpy_release(items[rest]);
            }
            jacpy_release(v);
            return ptr[PyObject]();
        }
        PyStructSequence_SetItem(v, i64(index), items[index]);
    }
    return v;
}
