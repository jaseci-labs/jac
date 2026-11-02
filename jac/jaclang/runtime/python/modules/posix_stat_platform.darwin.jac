"""The macOS side of the posix stat area: struct stat's extra fields
(st_flags, st_gen, st_birthtime) and os.statvfs over struct statfs.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
macOS's struct statvfs counts blocks in 32 bits, so os.statvfs reads
statfs(2) instead (the $INODE64 statfs, through the jacpy_statfs helpers).
"""

import from jaclang.runtime.python.cpython_api {
    PyFloat_FromDouble,
    PyLong_FromLong,
    PyLong_FromLongLong,
    PyLong_FromUnsignedLong,
    PyObject,
    jacpy_fstatfs,
    jacpy_release,
    jacpy_statfs
}
import from jaclang.runtime.python.object_model.structseq {
    PyStructSequence_New,
    PyStructSequence_SetItem
}
import from jaclang.runtime.python.modules.stat_records { _Py_stat_struct }
import from c {
    # struct statfs with 64-bit inodes; the name strings follow f_fssubtype.
    obj statfs_record {
        has f_bsize: u32 = 0,
            f_iosize: i32 = 0,
            f_blocks: u64 = 0,
            f_bfree: u64 = 0,
            f_bavail: u64 = 0,
            f_files: u64 = 0,
            f_ffree: u64 = 0,
            f_fsid_0: i32 = 0,
            f_fsid_1: i32 = 0,
            f_owner: u32 = 0,
            f_type: u32 = 0,
            f_flags: u32 = 0,
            f_fssubtype: u32 = 0;
    }
}

glob PLATFORM: str = "darwin",
     # sizeof(struct statfs)
     STATVFS_RECORD_SIZE: int = 2168,
     MNT_RDONLY: u32 = 1,
     MNT_NOSUID: u32 = 8,
     ST_RDONLY: i64 = 1,
     ST_NOSUID: i64 = 2,
     NAME_MAX: i64 = 255,
     STAT_EXTRA_FIELDS: list[tuple[str, str]] = [
         ("st_flags", "user defined flags for file"),
         ("st_gen", "generation number"),
         ("st_birthtime", "time of creation")
     ];

def stat_mode(st: _Py_stat_struct) -> i64 {
    return i64(st.st_mode);
}

def stat_nlink(st: _Py_stat_struct) -> i64 {
    return i64(st.st_nlink);
}

def stat_blksize(st: _Py_stat_struct) -> i64 {
    return i64(st.st_blksize);
}

# dev_t is a signed 32-bit int; its bits travel in a u64.
def stat_device(st: _Py_stat_struct) -> u64 {
    return u64(u32.wrap(st.st_dev));
}

def stat_rdev(st: _Py_stat_struct) -> u64 {
    return u64(u32.wrap(st.st_rdev));
}

# st_flags, st_gen and st_birthtime from `index` on: ST_FLAGS_IDX, ST_GEN_IDX
# and ST_BIRTHTIME_IDX.
def set_stat_extra(v: ptr[PyObject], index: i64, st: _Py_stat_struct) -> bool {
    flags = PyLong_FromLong(i64(st.st_flags));
    if not flags {
        return False;
    }
    PyStructSequence_SetItem(v, index, flags);
    generation = PyLong_FromLong(i64(st.st_gen));
    if not generation {
        return False;
    }
    PyStructSequence_SetItem(v, index + 1, generation);
    # bsec and bnsec are unsigned long in the C.
    bsec = u64.wrap(st.st_birthtime_sec);
    bnsec = u64.wrap(st.st_birthtime_nsec);
    birthtime = PyFloat_FromDouble(f64(bsec) + f64(bnsec) * 1e-9);
    if not birthtime {
        return False;
    }
    PyStructSequence_SetItem(v, index + 2, birthtime);
    return True;
}

def statvfs_path(path: ptr[u8], record: ptr) -> i32 {
    return jacpy_statfs(path, record);
}

def statvfs_fd(fd: i32, record: ptr) -> i32 {
    return jacpy_fstatfs(fd, record);
}

# _pystatvfs_fromstructstatfs()
def statvfs_result(result_type: ptr[PyObject], record: ptr) -> ptr[PyObject] {
    v = PyStructSequence_New(result_type);
    if not v {
        return v;
    }
    st = ptr[statfs_record](record).view(1)[0];
    flags = i64(0);
    if st.f_flags & MNT_RDONLY {
        flags = flags | ST_RDONLY;
    }
    if st.f_flags & MNT_NOSUID {
        flags = flags | ST_NOSUID;
    }
    items = [
        PyLong_FromLong(i64(st.f_iosize)),
        PyLong_FromLong(i64(st.f_bsize)),
        PyLong_FromLongLong(i64.wrap(st.f_blocks)),
        PyLong_FromLongLong(i64.wrap(st.f_bfree)),
        PyLong_FromLongLong(i64.wrap(st.f_bavail)),
        PyLong_FromLongLong(i64.wrap(st.f_files)),
        PyLong_FromLongLong(i64.wrap(st.f_ffree)),
        PyLong_FromLongLong(i64.wrap(st.f_ffree)),
        PyLong_FromLong(flags),
        PyLong_FromLong(NAME_MAX),
        PyLong_FromUnsignedLong(u64(u32.wrap(st.f_fsid_0)))
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
