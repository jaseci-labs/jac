"""File mode predicates, permission strings and stat constants.

Derived from CPython 3.14.6 Modules/_stat.c; see ../LICENSE.cpython. File type
and permission bits are POSIX and identical on every supported platform; the
BSD file flags that differ live in stat_platform.jac and its per-OS variants.
"""

import from jaclang.runtime.python.cpython_api {
    PyErr_Occurred,
    PyLong_AsUnsignedLong,
    PyNumber_Index,
    PyObject,
    jacpy_is_long,
    jacpy_release
}
import from jaclang.runtime.python.capi { boundary_failure, object_error }

glob S_IMODE: u64 = 0o7777,
     S_IFMT: u64 = 0o170000,
     S_IFDIR: u64 = 0o040000,
     S_IFCHR: u64 = 0o020000,
     S_IFBLK: u64 = 0o060000,
     S_IFREG: u64 = 0o100000,
     S_IFIFO: u64 = 0o010000,
     S_IFLNK: u64 = 0o120000,
     S_IFSOCK: u64 = 0o140000,
     S_IFDOOR: u64 = 0,
     S_IFPORT: u64 = 0,
     S_ISUID: u64 = 0o4000,
     S_ISGID: u64 = 0o2000,
     S_ISVTX: u64 = 0o1000,
     S_IRWXU: u64 = 0o700,
     S_IRUSR: u64 = 0o400,
     S_IWUSR: u64 = 0o200,
     S_IXUSR: u64 = 0o100,
     S_IRWXG: u64 = 0o070,
     S_IRGRP: u64 = 0o040,
     S_IWGRP: u64 = 0o020,
     S_IXGRP: u64 = 0o010,
     S_IRWXO: u64 = 0o007,
     S_IROTH: u64 = 0o004,
     S_IWOTH: u64 = 0o002,
     S_IXOTH: u64 = 0o001;

# _PyLong_AsMode_t: mode_t is 32 bits wide on every supported platform.
def mode_value(value: ptr[PyObject]) -> u64 {
    number: u64 = 0;
    if jacpy_is_long(value) != 0 {
        number = PyLong_AsUnsignedLong(value);
    } else {
        index = PyNumber_Index(value);
        if not index {
            raise boundary_failure();
        }
        number = PyLong_AsUnsignedLong(index);
        jacpy_release(index);
    }
    if number == u64(0xFFFFFFFFFFFFFFFF) and PyErr_Occurred() {
        raise boundary_failure();
    }
    if number > u64(0xFFFFFFFF) {
        object_error("OverflowError", "mode out of range");
        raise boundary_failure();
    }
    return number;
}

def is_type(mode: u64, kind: u64) -> bool {
    return kind != 0 and (mode & S_IFMT) == kind;
}

def type_character(mode: u64, whiteout: u64) -> str {
    kinds = [
        S_IFREG,
        S_IFDIR,
        S_IFLNK,
        S_IFBLK,
        S_IFCHR,
        S_IFIFO,
        S_IFSOCK,
        S_IFDOOR,
        S_IFPORT,
        whiteout
    ];
    marks = "-dlbcpsDPw";
    for index in range(len(kinds)) {
        if is_type(mode, kinds[index]) {
            return marks[index];
        }
    }
    return "?";
}

def permission(
    mode: u64, read: u64, write: u64, execute: u64, special: u64, set: str, unset: str
) -> str {
    text = ("r" if mode & read else "-") + ("w" if mode & write else "-");
    if mode & special {
        return text + (set if mode & execute else unset);
    }
    return text + ("x" if mode & execute else "-");
}

def filemode_text(mode: u64, whiteout: u64) -> str {
    return (
        type_character(mode, whiteout)
        + permission(mode, S_IRUSR, S_IWUSR, S_IXUSR, S_ISUID, "s", "S")
        + permission(mode, S_IRGRP, S_IWGRP, S_IXGRP, S_ISGID, "s", "S")
        + permission(mode, S_IROTH, S_IWOTH, S_IXOTH, S_ISVTX, "t", "T")
    );
}
