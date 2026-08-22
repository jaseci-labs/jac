# Product-path facade for _stat.
# Staged ``jac-py/Modules/_stat.jac`` remains the cc oracle extract
# (S_IMODE/S_IFMT only). Semantics mirror CPython 3.14 ``Modules/_stat.c``
# POSIX fallback values; UF_/SF_ file-flag constants are platform-dependent
# on the C build and are intentionally not exported here.

glob S_IFMT: int = 0o170000,
     S_IFDIR: int = 0o040000,
     S_IFCHR: int = 0o020000,
     S_IFBLK: int = 0o060000,
     S_IFREG: int = 0o100000,
     S_IFIFO: int = 0o010000,
     S_IFLNK: int = 0o120000,
     S_IFSOCK: int = 0o140000,

     S_ISUID: int = 0o4000,
     S_ISGID: int = 0o2000,
     S_ENFMT: int = 0o2000,
     S_ISVTX: int = 0o1000,
     S_IREAD: int = 0o400,
     S_IWRITE: int = 0o200,
     S_IEXEC: int = 0o100,
     S_IRWXU: int = 0o700,
     S_IRUSR: int = 0o400,
     S_IWUSR: int = 0o200,
     S_IXUSR: int = 0o100,
     S_IRWXG: int = 0o70,
     S_IRGRP: int = 0o40,
     S_IWGRP: int = 0o20,
     S_IXGRP: int = 0o10,
     S_IRWXO: int = 0o7,
     S_IROTH: int = 0o4,
     S_IWOTH: int = 0o2,
     S_IXOTH: int = 0o1,

     ST_MODE: int = 0,
     ST_INO: int = 1,
     ST_DEV: int = 2,
     ST_NLINK: int = 3,
     ST_UID: int = 4,
     ST_GID: int = 5,
     ST_SIZE: int = 6,
     ST_ATIME: int = 7,
     ST_MTIME: int = 8,
     ST_CTIME: int = 9;

def _p2_S_IMODE(mode: int) -> int {
    return mode & 0o7777;
}

def _p2_S_IFMT(mode: int) -> int {
    return mode & S_IFMT;
}

def _p2_S_ISDIR(mode: int) -> bool {
    return mode & S_IFMT == S_IFDIR;
}

def _p2_S_ISCHR(mode: int) -> bool {
    return mode & S_IFMT == S_IFCHR;
}

def _p2_S_ISBLK(mode: int) -> bool {
    return mode & S_IFMT == S_IFBLK;
}

def _p2_S_ISREG(mode: int) -> bool {
    return mode & S_IFMT == S_IFREG;
}

def _p2_S_ISFIFO(mode: int) -> bool {
    return mode & S_IFMT == S_IFIFO;
}

def _p2_S_ISLNK(mode: int) -> bool {
    return mode & S_IFMT == S_IFLNK;
}

def _p2_S_ISSOCK(mode: int) -> bool {
    return mode & S_IFMT == S_IFSOCK;
}

# Non-standard types absent on POSIX builds: C module falls back to literal 0.
def _p2_S_ISDOOR(mode: int) -> bool {
    return False;
}

def _p2_S_ISPORT(mode: int) -> bool {
    return False;
}

def _p2_S_ISWHT(mode: int) -> bool {
    return False;
}

def _p2_filemode(mode: int) -> str {
    if _p2_S_ISREG(mode) {
        ftype: str = "-";
    } elif _p2_S_ISDIR(mode) {
        ftype: str = "d";
    } elif _p2_S_ISLNK(mode) {
        ftype: str = "l";
    } elif _p2_S_ISBLK(mode) {
        ftype: str = "b";
    } elif _p2_S_ISCHR(mode) {
        ftype: str = "c";
    } elif _p2_S_ISFIFO(mode) {
        ftype: str = "p";
    } elif _p2_S_ISSOCK(mode) {
        ftype: str = "s";
    } else {
        ftype: str = "?";
    }
    perm: str = "";
    if mode & S_IRUSR { perm += "r"; } else { perm += "-"; }
    if mode & S_IWUSR { perm += "w"; } else { perm += "-"; }
    if mode & S_ISUID {
        if mode & S_IXUSR { perm += "s"; } else { perm += "S"; }
    } elif mode & S_IXUSR {
        perm += "x";
    } else {
        perm += "-";
    }
    if mode & S_IRGRP { perm += "r"; } else { perm += "-"; }
    if mode & S_IWGRP { perm += "w"; } else { perm += "-"; }
    if mode & S_ISGID {
        if mode & S_IXGRP { perm += "s"; } else { perm += "S"; }
    } elif mode & S_IXGRP {
        perm += "x";
    } else {
        perm += "-";
    }
    if mode & S_IROTH { perm += "r"; } else { perm += "-"; }
    if mode & S_IWOTH { perm += "w"; } else { perm += "-"; }
    if mode & S_ISVTX {
        if mode & S_IXOTH { perm += "t"; } else { perm += "T"; }
    } elif mode & S_IXOTH {
        perm += "x";
    } else {
        perm += "-";
    }
    return ftype + perm;
}
