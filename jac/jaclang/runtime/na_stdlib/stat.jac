glob ST_MODE: int = 0,
     ST_INO: int = 1,
     ST_DEV: int = 2,
     ST_NLINK: int = 3,
     ST_UID: int = 4,
     ST_GID: int = 5,
     ST_SIZE: int = 6,
     ST_ATIME: int = 7,
     ST_MTIME: int = 8,
     ST_CTIME: int = 9;

glob S_IFDIR: int = 0o040000,
     S_IFCHR: int = 0o020000,
     S_IFBLK: int = 0o060000,
     S_IFREG: int = 0o100000,
     S_IFIFO: int = 0o010000,
     S_IFLNK: int = 0o120000,
     S_IFSOCK: int = 0o140000,
     S_IFDOOR: int = 0,
     S_IFPORT: int = 0,
     S_IFWHT: int = 0;

glob S_ISUID: int = 0o4000,
     S_ISGID: int = 0o2000,
     S_ENFMT: int = 0o2000,
     S_ISVTX: int = 0o1000,
     S_IREAD: int = 0o0400,
     S_IWRITE: int = 0o0200,
     S_IEXEC: int = 0o0100,
     S_IRWXU: int = 0o0700,
     S_IRUSR: int = 0o0400,
     S_IWUSR: int = 0o0200,
     S_IXUSR: int = 0o0100,
     S_IRWXG: int = 0o0070,
     S_IRGRP: int = 0o0040,
     S_IWGRP: int = 0o0020,
     S_IXGRP: int = 0o0010,
     S_IRWXO: int = 0o0007,
     S_IROTH: int = 0o0004,
     S_IWOTH: int = 0o0002,
     S_IXOTH: int = 0o0001;

glob UF_SETTABLE: int = 0x0000ffff,
     UF_NODUMP: int = 0x00000001,
     UF_IMMUTABLE: int = 0x00000002,
     UF_APPEND: int = 0x00000004,
     UF_OPAQUE: int = 0x00000008,
     UF_NOUNLINK: int = 0x00000010,
     UF_COMPRESSED: int = 0x00000020,
     UF_TRACKED: int = 0x00000040,
     UF_DATAVAULT: int = 0x00000080,
     UF_HIDDEN: int = 0x00008000,
     SF_SETTABLE: int = 0xffff0000,
     SF_ARCHIVED: int = 0x00010000,
     SF_IMMUTABLE: int = 0x00020000,
     SF_APPEND: int = 0x00040000,
     SF_RESTRICTED: int = 0x00080000,
     SF_NOUNLINK: int = 0x00100000,
     SF_SNAPSHOT: int = 0x00200000,
     SF_FIRMLINK: int = 0x00800000,
     SF_DATALESS: int = 0x40000000;

def:pub S_IMODE(mode: int) -> int {
    return mode & 0o7777;
}

def:pub S_IFMT(mode: int) -> int {
    return mode & 0o170000;
}

def:pub S_ISDIR(mode: int) -> bool {
    return mode & 0o170000 == S_IFDIR;
}

def:pub S_ISCHR(mode: int) -> bool {
    return mode & 0o170000 == S_IFCHR;
}

def:pub S_ISBLK(mode: int) -> bool {
    return mode & 0o170000 == S_IFBLK;
}

def:pub S_ISREG(mode: int) -> bool {
    return mode & 0o170000 == S_IFREG;
}

def:pub S_ISFIFO(mode: int) -> bool {
    return mode & 0o170000 == S_IFIFO;
}

def:pub S_ISLNK(mode: int) -> bool {
    return mode & 0o170000 == S_IFLNK;
}

def:pub S_ISSOCK(mode: int) -> bool {
    return mode & 0o170000 == S_IFSOCK;
}

def:pub S_ISDOOR(mode: int) -> bool {
    return False;
}

def:pub S_ISPORT(mode: int) -> bool {
    return False;
}

def:pub S_ISWHT(mode: int) -> bool {
    return False;
}

def _rwx_triplet(
    mode: int, r: int, w: int, x: int, special: int, sx: str, snx: str
) -> str {
    out: str = "";
    if mode & r == r {
        out += "r";
    } else {
        out += "-";
    }
    if mode & w == w {
        out += "w";
    } else {
        out += "-";
    }
    if mode & (x | special) == (x | special) {
        out += sx;
    } elif mode & special == special {
        out += snx;
    } elif mode & x == x {
        out += "x";
    } else {
        out += "-";
    }
    return out;
}

def:pub filemode(mode: int) -> str {
    dtype: int = mode & 0o170000;
    head: str = "?";
    if dtype == S_IFLNK {
        head = "l";
    } elif dtype == S_IFSOCK {
        head = "s";
    } elif dtype == S_IFREG {
        head = "-";
    } elif dtype == S_IFBLK {
        head = "b";
    } elif dtype == S_IFDIR {
        head = "d";
    } elif dtype == S_IFCHR {
        head = "c";
    } elif dtype == S_IFIFO {
        head = "p";
    }
    return (
        head
        + _rwx_triplet(mode, 0o0400, 0o0200, 0o0100, S_ISUID, "s", "S")
        + _rwx_triplet(mode, 0o0040, 0o0020, 0o0010, S_ISGID, "s", "S")
        + _rwx_triplet(mode, 0o0004, 0o0002, 0o0001, S_ISVTX, "t", "T")
    );
}
