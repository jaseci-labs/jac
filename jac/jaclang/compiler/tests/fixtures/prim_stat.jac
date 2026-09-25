"""Bundled native ``stat`` cross-backend equivalence fixture.

The SAME `import from stat { ... }` binds CPython's ``stat`` on the sv
(Python) backend and the bundled `na_stdlib/stat.jac` Mechanism-B module on
the na (native LLVM) backend. Pure constant/predicate/string surface, so both
lanes compute identical values with no filesystem access. Pins the mode-bit
extraction helpers over a grid covering every S_IF* type plus setuid/setgid/
sticky combinations, every predicate on that grid, the S_I*/S_IF*/UF_/SF_/
ST_* constants, and ``filemode`` including the '?' unknown-type and the
s/S/t/T special-bit renderings. The na lane drives its grid through the
pinned `_stat_core_na` helper (na-side helpers are pinned per the
`prim_math`/`prim_base64` convention); the sv lane shares `_stat_core`.
ES/JS opts out.
"""

import from stat {
    S_IFMT,
    S_IMODE,
    S_ISBLK,
    S_ISCHR,
    S_ISDIR,
    S_ISDOOR,
    S_ISFIFO,
    S_ISLNK,
    S_ISPORT,
    S_ISREG,
    S_ISSOCK,
    S_ISWHT,
    S_IFBLK,
    S_IFCHR,
    S_IFDIR,
    S_IFDOOR,
    S_IFIFO,
    S_IFLNK,
    S_IFPORT,
    S_IFREG,
    S_IFSOCK,
    S_IFWHT,
    S_IEXEC,
    S_ENFMT,
    S_IRGRP,
    S_IROTH,
    S_IRUSR,
    S_IRWXG,
    S_IRWXO,
    S_IRWXU,
    S_ISGID,
    S_ISUID,
    S_ISVTX,
    S_IWGRP,
    S_IWOTH,
    S_IWUSR,
    S_IWRITE,
    S_IXGRP,
    S_IXOTH,
    S_IXUSR,
    S_IREAD,
    ST_MODE,
    ST_INO,
    ST_DEV,
    ST_NLINK,
    ST_UID,
    ST_GID,
    ST_SIZE,
    ST_ATIME,
    ST_MTIME,
    ST_CTIME,
    UF_NODUMP,
    UF_HIDDEN,
    SF_SNAPSHOT,
    filemode
}


def _stat_core(mode: int, tag: str, d: dict[any, any]) {
    d["imode_" + tag] = S_IMODE(mode);
    d["ifmt_" + tag] = S_IFMT(mode);
    d["isdir_" + tag] = S_ISDIR(mode);
    d["ischr_" + tag] = S_ISCHR(mode);
    d["isblk_" + tag] = S_ISBLK(mode);
    d["isreg_" + tag] = S_ISREG(mode);
    d["isfifo_" + tag] = S_ISFIFO(mode);
    d["islnk_" + tag] = S_ISLNK(mode);
    d["issock_" + tag] = S_ISSOCK(mode);
    d["isdoor_" + tag] = S_ISDOOR(mode);
    d["isport_" + tag] = S_ISPORT(mode);
    d["iswht_" + tag] = S_ISWHT(mode);
    d["fm_" + tag] = filemode(mode);
}


def stat_py -> dict[any, any] {
    d: dict[any, any] = {
        "c_ifdir": S_IFDIR,
        "c_ifchr": S_IFCHR,
        "c_ifblk": S_IFBLK,
        "c_ifreg": S_IFREG,
        "c_ififo": S_IFIFO,
        "c_iflnk": S_IFLNK,
        "c_ifsock": S_IFSOCK,
        "c_ifdoor": S_IFDOOR,
        "c_ifport": S_IFPORT,
        "c_ifwht": S_IFWHT,
        "c_isuid": S_ISUID,
        "c_isgid": S_ISGID,
        "c_enfmt": S_ENFMT,
        "c_isvtx": S_ISVTX,
        "c_iread": S_IREAD,
        "c_iwrite": S_IWRITE,
        "c_iexec": S_IEXEC,
        "c_irwxu": S_IRWXU,
        "c_irusr": S_IRUSR,
        "c_iwusr": S_IWUSR,
        "c_ixusr": S_IXUSR,
        "c_irwxg": S_IRWXG,
        "c_irgrp": S_IRGRP,
        "c_iwgrp": S_IWGRP,
        "c_ixgrp": S_IXGRP,
        "c_irwxo": S_IRWXO,
        "c_iroth": S_IROTH,
        "c_iwoth": S_IWOTH,
        "c_ixoth": S_IXOTH,
        "c_stmode": ST_MODE,
        "c_stino": ST_INO,
        "c_stdev": ST_DEV,
        "c_stnlink": ST_NLINK,
        "c_stuid": ST_UID,
        "c_stgid": ST_GID,
        "c_stsize": ST_SIZE,
        "c_statime": ST_ATIME,
        "c_stmtime": ST_MTIME,
        "c_stctime": ST_CTIME,
        "c_ufnodump": UF_NODUMP,
        "c_ufhidden": UF_HIDDEN,
        "c_sfsnapshot": SF_SNAPSHOT
    };
    _stat_core(0o100644, "reg644", d);
    _stat_core(0o100755, "reg755", d);
    _stat_core(0o100711, "reg711", d);
    _stat_core(0o00644, "plain", d);
    _stat_core(0o040755, "dir", d);
    _stat_core(0o120777, "lnk", d);
    _stat_core(0o020600, "chr", d);
    _stat_core(0o060640, "blk", d);
    _stat_core(0o010711, "fifo", d);
    _stat_core(0o140777, "sock", d);
    _stat_core(0o104755, "setuid", d);
    _stat_core(0o204755, "setgidx", d);
    _stat_core(0o201755, "setgid", d);
    _stat_core(0o101755, "stickyx", d);
    _stat_core(0o101000, "sticky", d);
    _stat_core(0o104711, "setuid711", d);
    _stat_core(0o000000, "zero", d);
    _stat_core(0o0777, "onlyperm", d);
    _stat_core(0o170000, "onlyfmt", d);
    _stat_core(0o07777, "fullbits", d);
    return d;
}


def stat_cl -> dict[any, any] {
    return {};
}


def _stat_core_na(mode: int, tag: str, d: dict[str, any]) {
    d["imode_" + tag] = S_IMODE(mode);
    d["ifmt_" + tag] = S_IFMT(mode);
    d["isdir_" + tag] = S_ISDIR(mode);
    d["ischr_" + tag] = S_ISCHR(mode);
    d["isblk_" + tag] = S_ISBLK(mode);
    d["isreg_" + tag] = S_ISREG(mode);
    d["isfifo_" + tag] = S_ISFIFO(mode);
    d["islnk_" + tag] = S_ISLNK(mode);
    d["issock_" + tag] = S_ISSOCK(mode);
    d["isdoor_" + tag] = S_ISDOOR(mode);
    d["isport_" + tag] = S_ISPORT(mode);
    d["iswht_" + tag] = S_ISWHT(mode);
    d["fm_" + tag] = filemode(mode);
}


def stat_na -> dict[str, any] {
    d: dict[str, any] = {
        "c_ifdir": S_IFDIR,
        "c_ifchr": S_IFCHR,
        "c_ifblk": S_IFBLK,
        "c_ifreg": S_IFREG,
        "c_ififo": S_IFIFO,
        "c_iflnk": S_IFLNK,
        "c_ifsock": S_IFSOCK,
        "c_ifdoor": S_IFDOOR,
        "c_ifport": S_IFPORT,
        "c_ifwht": S_IFWHT,
        "c_isuid": S_ISUID,
        "c_isgid": S_ISGID,
        "c_enfmt": S_ENFMT,
        "c_isvtx": S_ISVTX,
        "c_iread": S_IREAD,
        "c_iwrite": S_IWRITE,
        "c_iexec": S_IEXEC,
        "c_irwxu": S_IRWXU,
        "c_irusr": S_IRUSR,
        "c_iwusr": S_IWUSR,
        "c_ixusr": S_IXUSR,
        "c_irwxg": S_IRWXG,
        "c_irgrp": S_IRGRP,
        "c_iwgrp": S_IWGRP,
        "c_ixgrp": S_IXGRP,
        "c_irwxo": S_IRWXO,
        "c_iroth": S_IROTH,
        "c_iwoth": S_IWOTH,
        "c_ixoth": S_IXOTH,
        "c_stmode": ST_MODE,
        "c_stino": ST_INO,
        "c_stdev": ST_DEV,
        "c_stnlink": ST_NLINK,
        "c_stuid": ST_UID,
        "c_stgid": ST_GID,
        "c_stsize": ST_SIZE,
        "c_statime": ST_ATIME,
        "c_stmtime": ST_MTIME,
        "c_stctime": ST_CTIME,
        "c_ufnodump": UF_NODUMP,
        "c_ufhidden": UF_HIDDEN,
        "c_sfsnapshot": SF_SNAPSHOT
    };
    _stat_core_na(0o100644, "reg644", d);
    _stat_core_na(0o100755, "reg755", d);
    _stat_core_na(0o100711, "reg711", d);
    _stat_core_na(0o00644, "plain", d);
    _stat_core_na(0o040755, "dir", d);
    _stat_core_na(0o120777, "lnk", d);
    _stat_core_na(0o020600, "chr", d);
    _stat_core_na(0o060640, "blk", d);
    _stat_core_na(0o010711, "fifo", d);
    _stat_core_na(0o140777, "sock", d);
    _stat_core_na(0o104755, "setuid", d);
    _stat_core_na(0o204755, "setgidx", d);
    _stat_core_na(0o201755, "setgid", d);
    _stat_core_na(0o101755, "stickyx", d);
    _stat_core_na(0o101000, "sticky", d);
    _stat_core_na(0o104711, "setuid711", d);
    _stat_core_na(0o000000, "zero", d);
    _stat_core_na(0o0777, "onlyperm", d);
    _stat_core_na(0o170000, "onlyfmt", d);
    _stat_core_na(0o07777, "fullbits", d);
    return d;
}
