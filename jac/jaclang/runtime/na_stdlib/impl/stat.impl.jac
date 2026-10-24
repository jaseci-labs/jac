impl S_IMODE(mode: int) -> int {
    return mode & 0o7777;
}

impl S_IFMT(mode: int) -> int {
    return mode & 0o170000;
}

impl S_ISDIR(mode: int) -> bool {
    return mode & 0o170000 == S_IFDIR;
}

impl S_ISCHR(mode: int) -> bool {
    return mode & 0o170000 == S_IFCHR;
}

impl S_ISBLK(mode: int) -> bool {
    return mode & 0o170000 == S_IFBLK;
}

impl S_ISREG(mode: int) -> bool {
    return mode & 0o170000 == S_IFREG;
}

impl S_ISFIFO(mode: int) -> bool {
    return mode & 0o170000 == S_IFIFO;
}

impl S_ISLNK(mode: int) -> bool {
    return mode & 0o170000 == S_IFLNK;
}

impl S_ISSOCK(mode: int) -> bool {
    return mode & 0o170000 == S_IFSOCK;
}

impl S_ISDOOR(mode: int) -> bool {
    return False;
}

impl S_ISPORT(mode: int) -> bool {
    return False;
}

impl S_ISWHT(mode: int) -> bool {
    return False;
}

impl _rwx_triplet(
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

impl filemode(mode: int) -> str {
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
