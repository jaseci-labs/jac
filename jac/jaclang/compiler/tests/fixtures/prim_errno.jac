"""Bundled native ``errno`` cross-backend equivalence fixture.

The SAME `import from errno { ... }` binds CPython's ``errno`` on the sv
(Python) backend and the bundled `na_stdlib/errno.<os>.jac` module on the na
(native LLVM) backend. Pins a representative slice of the E* constants on the
running host -- including every value-aliased pair (EAGAIN/EWOULDBLOCK,
EDEADLK/EDEADLOCK, ENOTSUP/EOPNOTSUPP) and the extremes of the range -- the
``errorcode`` dict lookups for those values, and the ``KeyError`` raised for
a code with no name. ES/JS opts out.
"""

import from errno {
    EPERM,
    ENOENT,
    ESRCH,
    EINTR,
    EIO,
    E2BIG,
    EBADF,
    ECHILD,
    EAGAIN,
    EWOULDBLOCK,
    ENOMEM,
    EACCES,
    EFAULT,
    EBUSY,
    EEXIST,
    EXDEV,
    ENODEV,
    ENOTDIR,
    EISDIR,
    EINVAL,
    EMFILE,
    ENOSPC,
    EPIPE,
    EDOM,
    ERANGE,
    EDEADLK,
    EDEADLOCK,
    EINPROGRESS,
    ENOTSOCK,
    EADDRINUSE,
    ENETDOWN,
    ECONNRESET,
    ENOBUFS,
    EISCONN,
    ENOTCONN,
    ETIMEDOUT,
    ECONNREFUSED,
    ELOOP,
    ENAMETOOLONG,
    EHOSTUNREACH,
    ENOTEMPTY,
    EDQUOT,
    ESTALE,
    ENOLCK,
    ENOSYS,
    EOVERFLOW,
    ECANCELED,
    EIDRM,
    ENOMSG,
    EILSEQ,
    EBADMSG,
    ENOTRECOVERABLE,
    EOWNERDEAD,
    errorcode
}


def errno_py -> dict[any, any] {
    d: dict[any, any] = {
        "c_eperm": EPERM,
        "c_enoent": ENOENT,
        "c_esrch": ESRCH,
        "c_eintr": EINTR,
        "c_eio": EIO,
        "c_e2big": E2BIG,
        "c_ebadf": EBADF,
        "c_echild": ECHILD,
        "c_eagain": EAGAIN,
        "c_ewouldblock": EWOULDBLOCK,
        "c_enomem": ENOMEM,
        "c_eacces": EACCES,
        "c_efault": EFAULT,
        "c_ebusy": EBUSY,
        "c_eexist": EEXIST,
        "c_exdev": EXDEV,
        "c_enodev": ENODEV,
        "c_enotdir": ENOTDIR,
        "c_eisdir": EISDIR,
        "c_einval": EINVAL,
        "c_emfile": EMFILE,
        "c_enospc": ENOSPC,
        "c_epipe": EPIPE,
        "c_edom": EDOM,
        "c_erange": ERANGE,
        "c_edeadlk": EDEADLK,
        "c_edeadlock": EDEADLOCK,
        "c_einprogress": EINPROGRESS,
        "c_enotsock": ENOTSOCK,
        "c_eaddrinuse": EADDRINUSE,
        "c_enetdown": ENETDOWN,
        "c_econnreset": ECONNRESET,
        "c_enobufs": ENOBUFS,
        "c_eisconn": EISCONN,
        "c_enotconn": ENOTCONN,
        "c_etimedout": ETIMEDOUT,
        "c_econnrefused": ECONNREFUSED,
        "c_eloop": ELOOP,
        "c_enametoolong": ENAMETOOLONG,
        "c_ehostunreach": EHOSTUNREACH,
        "c_enotempty": ENOTEMPTY,
        "c_edquot": EDQUOT,
        "c_estale": ESTALE,
        "c_enolck": ENOLCK,
        "c_enosys": ENOSYS,
        "c_eoverflow": EOVERFLOW,
        "c_ecanceled": ECANCELED,
        "c_eidrm": EIDRM,
        "c_enomsg": ENOMSG,
        "c_eilseq": EILSEQ,
        "c_ebadmsg": EBADMSG,
        "c_enotrecoverable": ENOTRECOVERABLE,
        "c_eownerdead": EOWNERDEAD,
        "ec_enoent": errorcode[ENOENT],
        "ec_2": errorcode[2],
        "ec_11": errorcode[11],
        "ec_13": errorcode[13],
        "ec_35": errorcode[35],
        "ec_95": errorcode[95]
    };
    err: str = "no raise";
    try {
        errorcode[99999];
    } except KeyError {
        err = "KeyError";
    } except Exception {
        err = "WRONG-TYPE";
    }
    d["ec_missing"] = err;
    return d;
}


def errno_cl -> dict[any, any] {
    return {};
}


def errno_na -> dict[str, any] {
    d: dict[str, any] = {
        "c_eperm": EPERM,
        "c_enoent": ENOENT,
        "c_esrch": ESRCH,
        "c_eintr": EINTR,
        "c_eio": EIO,
        "c_e2big": E2BIG,
        "c_ebadf": EBADF,
        "c_echild": ECHILD,
        "c_eagain": EAGAIN,
        "c_ewouldblock": EWOULDBLOCK,
        "c_enomem": ENOMEM,
        "c_eacces": EACCES,
        "c_efault": EFAULT,
        "c_ebusy": EBUSY,
        "c_eexist": EEXIST,
        "c_exdev": EXDEV,
        "c_enodev": ENODEV,
        "c_enotdir": ENOTDIR,
        "c_eisdir": EISDIR,
        "c_einval": EINVAL,
        "c_emfile": EMFILE,
        "c_enospc": ENOSPC,
        "c_epipe": EPIPE,
        "c_edom": EDOM,
        "c_erange": ERANGE,
        "c_edeadlk": EDEADLK,
        "c_edeadlock": EDEADLOCK,
        "c_einprogress": EINPROGRESS,
        "c_enotsock": ENOTSOCK,
        "c_eaddrinuse": EADDRINUSE,
        "c_enetdown": ENETDOWN,
        "c_econnreset": ECONNRESET,
        "c_enobufs": ENOBUFS,
        "c_eisconn": EISCONN,
        "c_enotconn": ENOTCONN,
        "c_etimedout": ETIMEDOUT,
        "c_econnrefused": ECONNREFUSED,
        "c_eloop": ELOOP,
        "c_enametoolong": ENAMETOOLONG,
        "c_ehostunreach": EHOSTUNREACH,
        "c_enotempty": ENOTEMPTY,
        "c_edquot": EDQUOT,
        "c_estale": ESTALE,
        "c_enolck": ENOLCK,
        "c_enosys": ENOSYS,
        "c_eoverflow": EOVERFLOW,
        "c_ecanceled": ECANCELED,
        "c_eidrm": EIDRM,
        "c_enomsg": ENOMSG,
        "c_eilseq": EILSEQ,
        "c_ebadmsg": EBADMSG,
        "c_enotrecoverable": ENOTRECOVERABLE,
        "c_eownerdead": EOWNERDEAD,
        "ec_enoent": errorcode[ENOENT],
        "ec_2": errorcode[2],
        "ec_11": errorcode[11],
        "ec_13": errorcode[13],
        "ec_35": errorcode[35],
        "ec_95": errorcode[95]
    };
    err: str = "no raise";
    try {
        errorcode[99999];
    } except KeyError {
        err = "KeyError";
    } except Exception {
        err = "WRONG-TYPE";
    }
    d["ec_missing"] = err;
    return d;
}
