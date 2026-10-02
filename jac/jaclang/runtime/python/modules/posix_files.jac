"""The posix module's file system functions: access, the working directory,
modes, owners and flags, links, renames, directories, times, fifos and
device nodes, truncation, path configuration, extended attributes, lockf and
umask.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
The configure feature macros are the FEATURES of posix_constants.<os>.jac;
the *at() run-time checks hold on every supported deployment target except
mkfifoat() and mknodat() on macOS, which posix_files_platform.darwin.jac
looks up. Calls whose symbol or ABI differs by OS live in
posix_files_platform.<os>.jac.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_AsString,
    PyBytes_FromStringAndSize,
    PyErr_CheckSignals,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetString,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_OverflowError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyList_Append,
    PyList_New,
    PyLong_AsLong,
    PyLong_FromLong,
    PyLong_FromUnsignedLong,
    PyMem_Calloc,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawFree,
    PyMem_RawRealloc,
    PyNumber_Divmod,
    PyObject,
    PySys_Audit,
    PyTuple_GetItem,
    PyTuple_Pack,
    PyTuple_Size,
    PyUnicode_DecodeFSDefault,
    PyUnicode_DecodeFSDefaultAndSize,
    PyUnicode_EncodeFSDefault,
    PyUnicode_FromOrdinal,
    PyUnicode_FromWideChar,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    _PyBytes_Resize,
    _PyLong_AsTime_t,
    _PyTime_ObjectToTimespec,
    _PyType_Name,
    _Py_normpath_and_size,
    _Py_skiproot,
    jacpy_errno,
    jacpy_is_bytes,
    jacpy_is_exact_tuple,
    jacpy_is_tuple,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_set_errno
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.modules.time_records { timespec }
import from jaclang.runtime.python.modules.posix_core {
    DEFAULT_DIR_FD,
    STATE_BILLION,
    argument_unavailable_error,
    dev_value,
    dir_fd_and_fd_invalid,
    dir_fd_and_follow_symlinks_invalid,
    fd_and_follow_symlinks_invalid,
    follow_symlinks_specified,
    path_and_dir_fd_invalid,
    path_error,
    path_error2,
    path_object_error,
    path_t,
    posix_error,
    posix_fildes_fd,
    posix_path_error,
    state_object
}
import from jaclang.runtime.python.modules.posix_platform { DEV_T_SIGNED_32 }
import from jaclang.runtime.python.modules.posix_constants {
    AT_EACCESS,
    AT_REMOVEDIR,
    AT_SYMLINK_FOLLOW,
    AT_SYMLINK_NOFOLLOW,
    EINTR,
    EINVAL,
    ENOENT,
    ENOSYS,
    ENOTSUP,
    EOPNOTSUPP,
    ERANGE,
    HAVE_FACCESSAT,
    HAVE_FCHDIR,
    HAVE_FCHMOD,
    HAVE_FCHMODAT,
    HAVE_FCHOWN,
    HAVE_FCHOWNAT,
    HAVE_FPATHCONF,
    HAVE_FUTIMENS,
    HAVE_FUTIMES,
    HAVE_FUTIMESAT,
    HAVE_LCHFLAGS,
    HAVE_LCHMOD,
    HAVE_LCHOWN,
    HAVE_LINKAT,
    HAVE_LUTIMES,
    HAVE_MKDIRAT,
    HAVE_MKFIFOAT,
    HAVE_MKNODAT,
    HAVE_READLINKAT,
    HAVE_RENAMEAT,
    HAVE_SYMLINKAT,
    HAVE_UNLINKAT,
    HAVE_UTIMENSAT,
    MAXPATHLEN,
    NODEV,
    XATTR_LIST_MAX,
    XATTR_SIZE_MAX
}
import from jaclang.runtime.python.modules.posix_files_platform {
    umask_call,
    MODE_T_MASK,
    PLATFORM,
    chflags_call,
    dev_major,
    dev_makedev,
    dev_minor,
    lchflags_call,
    lchmod_call,
    mkfifoat_available,
    mkfifoat_call,
    mknod_call,
    mknodat_available,
    mknodat_call,
    posix_fadvise_call,
    posix_fallocate_call,
    xattr_get,
    xattr_list,
    xattr_remove,
    xattr_set
}
# Portable calls; mode_t travels as a zero-extended u32 masked to its width.
import from c {
    def access(path: ptr[u8], mode: i32) -> i32;  def faccessat(
        dir_fd: i32, path: ptr[u8], mode: i32, flags: i32
    ) -> i32;  def chdir(path: ptr[u8]) -> i32;  def fchdir(fd: i32) -> i32;  def chmod(
        path: ptr[u8], mode: u32
    ) -> i32;  def fchmod(fd: i32, mode: u32) -> i32;  def fchmodat(
        dir_fd: i32, path: ptr[u8], mode: u32, flags: i32
    ) -> i32;  def chroot(path: ptr[u8]) -> i32;  def sync;  def chown(
        path: ptr[u8], uid: u32, gid: u32
    ) -> i32;  def fchown(fd: i32, uid: u32, gid: u32) -> i32;  def lchown(
        path: ptr[u8], uid: u32, gid: u32
    ) -> i32;  def fchownat(
        dir_fd: i32, path: ptr[u8], uid: u32, gid: u32, flags: i32
    ) -> i32;  def getcwd(buffer: ptr[u8], size: u64) -> ptr[u8];  def strlen(
        text: ptr[u8]
    ) -> u64;  def link(src: ptr[u8], dst: ptr[u8]) -> i32;  def linkat(
        src_dir_fd: i32, src: ptr[u8], dst_dir_fd: i32, dst: ptr[u8], flags: i32
    ) -> i32;  def mkdir(path: ptr[u8], mode: u32) -> i32;  def mkdirat(
        dir_fd: i32, path: ptr[u8], mode: u32
    ) -> i32;  def rename(src: ptr[u8], dst: ptr[u8]) -> i32;  def renameat(
        src_dir_fd: i32, src: ptr[u8], dst_dir_fd: i32, dst: ptr[u8]
    ) -> i32;  def rmdir(path: ptr[u8]) -> i32;  def unlink(path: ptr[u8]) -> i32;  def unlinkat(
        dir_fd: i32, path: ptr[u8], flags: i32
    ) -> i32;  def readlink(path: ptr[u8], buffer: ptr[u8], size: u64) -> i64;  def readlinkat(
        dir_fd: i32, path: ptr[u8], buffer: ptr[u8], size: u64
    ) -> i64;  def symlink(src: ptr[u8], dst: ptr[u8]) -> i32;  def symlinkat(
        src: ptr[u8], dir_fd: i32, dst: ptr[u8]
    ) -> i32;  def utimensat(
        dir_fd: i32, path: ptr[u8], times: ptr[timespec], flags: i32
    ) -> i32;  def futimens(fd: i32, times: ptr[timespec]) -> i32;  def mkfifo(
        path: ptr[u8], mode: u32
    ) -> i32;  def lockf(fd: i32, command: i32, length: i64) -> i32;  def ftruncate(
        fd: i32, length: i64
    ) -> i32;  def truncate(path: ptr[u8], length: i64) -> i32;  def fpathconf(
        fd: i32, name: i32
    ) -> i64;  def pathconf(path: ptr[u8], name: i32) -> i64;
}

glob:priv PY_SSIZE_T_MAX: u64 = u64(0x7FFFFFFFFFFFFFFF),
     _PyTime_ROUND_FLOOR: i32 = 0,
     TIMESPEC_SIZE: u64 = 16;

def posix_files_exec(module: ptr[PyObject]) -> bool {
    return True;
}

def:priv mode_t(mode: i32) -> u32 {
    return u32.wrap(mode) & MODE_T_MASK;
}

def:priv audit_dir_fd(dir_fd: i32) -> i32 {
    return i32(-1) if dir_fd == DEFAULT_DIR_FD else dir_fd;
}

def:priv none -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}

# --- access and the working directory --------------------------------------

def os_access_impl(
    module: ptr[PyObject],
    path: path_t,
    mode: i32,
    dir_fd: i32,
    effective_ids: bool,
    follow_symlinks: bool
) -> i32 {
    if not HAVE_FACCESSAT {
        if follow_symlinks_specified("access", follow_symlinks) {
            return i32(-1);
        }
        if effective_ids {
            argument_unavailable_error("access", "effective_ids");
            return i32(-1);
        }
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_FACCESSAT
        and (dir_fd != DEFAULT_DIR_FD or effective_ids or not follow_symlinks) {
        flags = i32(0);
        if not follow_symlinks {
            flags |= i32(AT_SYMLINK_NOFOLLOW);
        }
        if effective_ids {
            flags |= i32(AT_EACCESS);
        }
        result = faccessat(dir_fd, narrow, mode, flags);
    } else {
        result = access(narrow, mode);
    }
    PyEval_RestoreThread(thread);
    return i32(1) if result == 0 else i32(0);
}

def os_chdir_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
    if PySys_Audit("os.chdir", "(O)", path.object) < 0 {
        return NULL;
    }
    fd = path.fd;
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_FCHDIR and fd != -1 {
        result = fchdir(fd);
    } else {
        result = chdir(narrow);
    }
    PyEval_RestoreThread(thread);
    if result != 0 {
        return path_error(path);
    }
    return none();
}

def os_fchdir_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    if PySys_Audit("os.chdir", "(i)", fd) < 0 {
        return NULL;
    }
    return posix_fildes_fd(fd, 2);
}

# posix_getcwd(): the working directory as str, or bytes when `use_bytes`,
# growing the buffer a chunk at a time while getcwd() reports ERANGE.
def:priv posix_getcwd(use_bytes: bool) -> ptr[PyObject] {
    chunk = u64(1024);
    buffer = ptr[u8]();
    cwd = ptr[u8]();
    buffer_length = u64(0);
    thread = PyEval_SaveThread();
    while True {
        grown = ptr();
        if buffer_length <= PY_SSIZE_T_MAX - chunk {
            buffer_length += chunk;
            grown = PyMem_RawRealloc(ptr(buffer), buffer_length);
        }
        if not grown {
            PyMem_RawFree(ptr(buffer));
            buffer = ptr[u8]();
            break;
        }
        buffer = ptr[u8](grown);
        cwd = getcwd(buffer, buffer_length);
        if cwd or jacpy_errno() != ERANGE {
            break;
        }
    }
    PyEval_RestoreThread(thread);
    if not buffer {
        return PyErr_NoMemory();
    }
    if not cwd {
        posix_error();
        PyMem_RawFree(ptr(buffer));
        return NULL;
    }
    result = NULL;
    if use_bytes {
        result = PyBytes_FromStringAndSize(buffer, i64(strlen(buffer)));
    } else {
        result = PyUnicode_DecodeFSDefault(buffer);
    }
    if PLATFORM == "linux" and buffer.view(1)[0] != u8(47) {
        # Linux >= 2.6.36 with glibc < 2.27 can return a relative path
        # starting with '(unreachable)'; fail with ENOENT as newer glibc does.
        jacpy_set_errno(ENOENT);
        path_object_error(result);
        jacpy_release(result);
        PyMem_RawFree(ptr(buffer));
        return NULL;
    }
    PyMem_RawFree(ptr(buffer));
    return result;
}

def os_getcwd_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return posix_getcwd(False);
}

def os_getcwdb_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return posix_getcwd(True);
}

# --- modes, owners and flags -------------------------------------------------

def os_chmod_impl(
    module: ptr[PyObject], path: path_t, mode: i32, dir_fd: i32, follow_symlinks: bool
) -> ptr[PyObject] {
    fchmodat_nofollow_unsupported = False;
    if not (HAVE_FCHMODAT or HAVE_LCHMOD) {
        if follow_symlinks_specified("chmod", follow_symlinks) {
            return NULL;
        }
    }
    if PySys_Audit("os.chmod", "Oii", path.object, mode, audit_dir_fd(dir_fd)) < 0 {
        return NULL;
    }
    fd = path.fd;
    narrow = path.narrow;
    used_fchmodat = False;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_FCHMOD and fd != -1 {
        result = fchmod(fd, mode_t(mode));
    } elif HAVE_LCHMOD and not follow_symlinks and dir_fd == DEFAULT_DIR_FD {
        result = lchmod_call(narrow, mode_t(mode));
    } elif HAVE_FCHMODAT and (dir_fd != DEFAULT_DIR_FD or not follow_symlinks) {
        # fchmodat() may not support AT_SYMLINK_NOFOLLOW (glibc); that
        # failure becomes the NotImplementedError below.
        result = fchmodat(
            dir_fd,
            narrow,
            mode_t(mode),
            i32(0) if follow_symlinks else i32(AT_SYMLINK_NOFOLLOW)
        );
        used_fchmodat = True;
    } else {
        result = chmod(narrow, mode_t(mode));
    }
    PyEval_RestoreThread(thread);
    if result != 0 {
        if used_fchmodat {
            error = jacpy_errno();
            fchmodat_nofollow_unsupported = (error == ENOTSUP or error == EOPNOTSUPP)
                and not follow_symlinks;
        }
        if fchmodat_nofollow_unsupported {
            if dir_fd != DEFAULT_DIR_FD {
                dir_fd_and_follow_symlinks_invalid("chmod", dir_fd, follow_symlinks);
            } else {
                follow_symlinks_specified("chmod", follow_symlinks);
            }
            return NULL;
        }
        return path_error(path);
    }
    return none();
}

def os_fchmod_impl(module: ptr[PyObject], fd: i32, mode: i32) -> ptr[PyObject] {
    if PySys_Audit("os.chmod", "iii", fd, mode, i32(-1)) < 0 {
        return NULL;
    }
    async_err = False;
    result = i32(0);
    while True {
        thread = PyEval_SaveThread();
        result = fchmod(fd, mode_t(mode));
        PyEval_RestoreThread(thread);
        if result != 0 and jacpy_errno() == EINTR {
            if PyErr_CheckSignals() != 0 {
                async_err = True;
                break;
            }
            continue;
        }
        break;
    }
    if result != 0 {
        return NULL if async_err else posix_error();
    }
    return none();
}

def os_lchmod_impl(module: ptr[PyObject], path: path_t, mode: i32) -> ptr[PyObject] {
    if PySys_Audit("os.chmod", "Oii", path.object, mode, i32(-1)) < 0 {
        return NULL;
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = lchmod_call(narrow, mode_t(mode));
    PyEval_RestoreThread(thread);
    if result < 0 {
        path_error(path);
        return NULL;
    }
    return none();
}

def os_chflags_impl(
    module: ptr[PyObject], path: path_t, flags: u64, follow_symlinks: bool
) -> ptr[PyObject] {
    if not HAVE_LCHFLAGS {
        if follow_symlinks_specified("chflags", follow_symlinks) {
            return NULL;
        }
    }
    if PySys_Audit("os.chflags", "Ok", path.object, flags) < 0 {
        return NULL;
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_LCHFLAGS and not follow_symlinks {
        result = lchflags_call(narrow, flags);
    } else {
        result = chflags_call(narrow, flags);
    }
    PyEval_RestoreThread(thread);
    if result != 0 {
        return path_error(path);
    }
    return none();
}

def os_lchflags_impl(module: ptr[PyObject], path: path_t, flags: u64) -> ptr[PyObject] {
    if PySys_Audit("os.chflags", "Ok", path.object, flags) < 0 {
        return NULL;
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = lchflags_call(narrow, flags);
    PyEval_RestoreThread(thread);
    if result < 0 {
        return path_error(path);
    }
    return none();
}

def os_chroot_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = chroot(narrow);
    PyEval_RestoreThread(thread);
    if result < 0 {
        return path_error(path);
    }
    return none();
}

def os_fsync_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    return posix_fildes_fd(fd, 0);
}

def os_sync_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    sync();
    PyEval_RestoreThread(thread);
    return none();
}

def os_fdatasync_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    return posix_fildes_fd(fd, 1);
}

def os_chown_impl(
    module: ptr[PyObject],
    path: path_t,
    uid: u32,
    gid: u32,
    dir_fd: i32,
    follow_symlinks: bool
) -> ptr[PyObject] {
    if not (HAVE_LCHOWN or HAVE_FCHOWNAT) {
        if follow_symlinks_specified("chown", follow_symlinks) {
            return NULL;
        }
    }
    if dir_fd_and_fd_invalid("chown", dir_fd, path.fd)
        or fd_and_follow_symlinks_invalid("chown", path.fd, follow_symlinks) {
        return NULL;
    }
    if PySys_Audit("os.chown", "OIIi", path.object, uid, gid, audit_dir_fd(dir_fd))
        < 0 {
        return NULL;
    }
    fd = path.fd;
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_FCHOWN and fd != -1 {
        result = fchown(fd, uid, gid);
    } elif HAVE_LCHOWN and not follow_symlinks and dir_fd == DEFAULT_DIR_FD {
        result = lchown(narrow, uid, gid);
    } elif HAVE_FCHOWNAT and (dir_fd != DEFAULT_DIR_FD or not follow_symlinks) {
        result = fchownat(
            dir_fd,
            narrow,
            uid,
            gid,
            i32(0) if follow_symlinks else i32(AT_SYMLINK_NOFOLLOW)
        );
    } else {
        result = chown(narrow, uid, gid);
    }
    PyEval_RestoreThread(thread);
    if result != 0 {
        return path_error(path);
    }
    return none();
}

def os_fchown_impl(
    module: ptr[PyObject], fd: i32, uid: u32, gid: u32
) -> ptr[PyObject] {
    if PySys_Audit("os.chown", "iIIi", fd, uid, gid, i32(-1)) < 0 {
        return NULL;
    }
    async_err = False;
    result = i32(0);
    while True {
        thread = PyEval_SaveThread();
        result = fchown(fd, uid, gid);
        PyEval_RestoreThread(thread);
        if result != 0 and jacpy_errno() == EINTR {
            if PyErr_CheckSignals() != 0 {
                async_err = True;
                break;
            }
            continue;
        }
        break;
    }
    if result != 0 {
        return NULL if async_err else posix_error();
    }
    return none();
}

def os_lchown_impl(
    module: ptr[PyObject], path: path_t, uid: u32, gid: u32
) -> ptr[PyObject] {
    if PySys_Audit("os.chown", "OIIi", path.object, uid, gid, i32(-1)) < 0 {
        return NULL;
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = lchown(narrow, uid, gid);
    PyEval_RestoreThread(thread);
    if result < 0 {
        return path_error(path);
    }
    return none();
}

# --- links, renames and directories -----------------------------------------

def os_link_impl(
    module: ptr[PyObject],
    src: path_t,
    dst: path_t,
    src_dir_fd: i32,
    dst_dir_fd: i32,
    follow_symlinks: i32
) -> ptr[PyObject] {
    if HAVE_LINKAT {
        # -1: not given.
        if follow_symlinks < 0 {
            follow_symlinks = i32(1);
        }
    } else {
        if src_dir_fd != DEFAULT_DIR_FD or dst_dir_fd != DEFAULT_DIR_FD {
            argument_unavailable_error("link", "src_dir_fd and dst_dir_fd");
            return NULL;
        }
        # link() on Linux works like linkat() without AT_SYMLINK_FOLLOW, on
        # macOS like linkat() with it (issue 85527).
        if PLATFORM == "linux" and follow_symlinks == 1 {
            argument_unavailable_error("link", "follow_symlinks=True");
            return NULL;
        }
        if PLATFORM != "linux" and follow_symlinks == 0 {
            argument_unavailable_error("link", "follow_symlinks=False");
            return NULL;
        }
    }
    if PySys_Audit(
        "os.link",
        "OOii",
        src.object,
        dst.object,
        audit_dir_fd(src_dir_fd),
        audit_dir_fd(dst_dir_fd)
    )
        < 0 {
        return NULL;
    }
    source = src.narrow;
    target = dst.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_LINKAT {
        result = linkat(
            src_dir_fd,
            source,
            dst_dir_fd,
            target,
            i32(AT_SYMLINK_FOLLOW) if follow_symlinks != 0 else i32(0)
        );
    } else {
        result = link(source, target);
    }
    PyEval_RestoreThread(thread);
    if result != 0 {
        return path_error2(src, dst);
    }
    return none();
}

def os_mkdir_impl(
    module: ptr[PyObject], path: path_t, mode: i32, dir_fd: i32
) -> ptr[PyObject] {
    if PySys_Audit("os.mkdir", "Oii", path.object, mode, audit_dir_fd(dir_fd)) < 0 {
        return NULL;
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_MKDIRAT and dir_fd != DEFAULT_DIR_FD {
        result = mkdirat(dir_fd, narrow, mode_t(mode));
    } else {
        result = mkdir(narrow, mode_t(mode));
    }
    PyEval_RestoreThread(thread);
    if result < 0 {
        return path_error(path);
    }
    return none();
}

def internal_rename(
    src: path_t, dst: path_t, src_dir_fd: i32, dst_dir_fd: i32, is_replace: bool
) -> ptr[PyObject] {
    function_name = "replace" if is_replace else "rename";
    dir_fd_specified = src_dir_fd != DEFAULT_DIR_FD or dst_dir_fd != DEFAULT_DIR_FD;
    if not HAVE_RENAMEAT and dir_fd_specified {
        argument_unavailable_error(function_name, "src_dir_fd and dst_dir_fd");
        return NULL;
    }
    if PySys_Audit(
        "os.rename",
        "OOii",
        src.object,
        dst.object,
        audit_dir_fd(src_dir_fd),
        audit_dir_fd(dst_dir_fd)
    )
        < 0 {
        return NULL;
    }
    source = src.narrow;
    target = dst.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_RENAMEAT and dir_fd_specified {
        result = renameat(src_dir_fd, source, dst_dir_fd, target);
    } else {
        result = rename(source, target);
    }
    PyEval_RestoreThread(thread);
    if result != 0 {
        return path_error2(src, dst);
    }
    return none();
}

def os_rename_impl(
    module: ptr[PyObject], src: path_t, dst: path_t, src_dir_fd: i32, dst_dir_fd: i32
) -> ptr[PyObject] {
    return internal_rename(src, dst, src_dir_fd, dst_dir_fd, False);
}

def os_replace_impl(
    module: ptr[PyObject], src: path_t, dst: path_t, src_dir_fd: i32, dst_dir_fd: i32
) -> ptr[PyObject] {
    return internal_rename(src, dst, src_dir_fd, dst_dir_fd, True);
}

def os_rmdir_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject] {
    if PySys_Audit("os.rmdir", "Oi", path.object, audit_dir_fd(dir_fd)) < 0 {
        return NULL;
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_UNLINKAT and dir_fd != DEFAULT_DIR_FD {
        result = unlinkat(dir_fd, narrow, i32(AT_REMOVEDIR));
    } else {
        result = rmdir(narrow);
    }
    PyEval_RestoreThread(thread);
    if result != 0 {
        return path_error(path);
    }
    return none();
}

def os_umask_impl(module: ptr[PyObject], mask: i32) -> ptr[PyObject] {
    previous = i32.wrap(umask_call(mode_t(mask)) & MODE_T_MASK);
    if previous < 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(previous));
}

def os_unlink_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject] {
    if PySys_Audit("os.remove", "Oi", path.object, audit_dir_fd(dir_fd)) < 0 {
        return NULL;
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_UNLINKAT and dir_fd != DEFAULT_DIR_FD {
        result = unlinkat(dir_fd, narrow, i32(0));
    } else {
        result = unlink(narrow);
    }
    PyEval_RestoreThread(thread);
    if result != 0 {
        return path_error(path);
    }
    return none();
}

def os_remove_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject] {
    return os_unlink_impl(module, path, dir_fd);
}

def os_readlink_impl(
    module: ptr[PyObject], path: path_t, dir_fd: i32
) -> ptr[PyObject] {
    # char buffer[MAXPATHLEN+1]
    buffer = ptr[u8](PyMem_Malloc(u64(MAXPATHLEN + 1)));
    if not buffer {
        return PyErr_NoMemory();
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    length = i64(0);
    if HAVE_READLINKAT and dir_fd != DEFAULT_DIR_FD {
        length = readlinkat(dir_fd, narrow, buffer, u64(MAXPATHLEN));
    } else {
        length = readlink(narrow, buffer, u64(MAXPATHLEN));
    }
    PyEval_RestoreThread(thread);
    if length < 0 {
        PyMem_Free(ptr(buffer));
        return path_error(path);
    }
    (buffer + length).view(1)[0] = u8(0);
    result = NULL;
    if jacpy_is_unicode(path.object) != 0 {
        result = PyUnicode_DecodeFSDefaultAndSize(buffer, length);
    } else {
        result = PyBytes_FromStringAndSize(buffer, length);
    }
    PyMem_Free(ptr(buffer));
    return result;
}

def os_symlink_impl(
    module: ptr[PyObject],
    src: path_t,
    dst: path_t,
    target_is_directory: bool,
    dir_fd: i32
) -> ptr[PyObject] {
    if PySys_Audit("os.symlink", "OOi", src.object, dst.object, audit_dir_fd(dir_fd))
        < 0 {
        return NULL;
    }
    source = src.narrow;
    target = dst.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if HAVE_SYMLINKAT and dir_fd != DEFAULT_DIR_FD {
        result = symlinkat(source, dir_fd, target);
    } else {
        result = symlink(source, target);
    }
    PyEval_RestoreThread(thread);
    if result != 0 {
        return path_error2(src, dst);
    }
    return none();
}

# --- path strings ------------------------------------------------------------

def os__path_splitroot_ex_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
    buffer = ptr[i32](int(path.wide));
    drvsize = i64(0);
    rootsize = i64(0);
    _Py_skiproot(buffer, path.length, &mut drvsize, &mut rootsize);
    drv = NULL;
    root_part = NULL;
    tail = NULL;
    result = NULL;
    drv = PyUnicode_FromWideChar(buffer, drvsize);
    if drv {
        root_part = PyUnicode_FromWideChar(buffer + drvsize, rootsize);
    }
    if root_part {
        tail = PyUnicode_FromWideChar(
            buffer + (drvsize + rootsize), path.length - drvsize - rootsize
        );
    }
    complete = bool(tail);
    if complete and jacpy_is_bytes(path.object) != 0 {
        encoded = PyUnicode_EncodeFSDefault(drv);
        jacpy_release(drv);
        drv = encoded;
        if drv {
            encoded = PyUnicode_EncodeFSDefault(root_part);
            jacpy_release(root_part);
            root_part = encoded;
        }
        if drv and root_part {
            encoded = PyUnicode_EncodeFSDefault(tail);
            jacpy_release(tail);
            tail = encoded;
        }
        complete = bool(drv) and bool(root_part) and bool(tail);
    }
    if complete {
        result = PyTuple_Pack(3, drv, root_part, tail);
    }
    jacpy_release(drv);
    jacpy_release(root_part);
    jacpy_release(tail);
    return result;
}

def os__path_normpath_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
    norm_len = i64(0);
    norm_path = _Py_normpath_and_size(
        ptr[i32](int(path.wide)), path.length, &mut norm_len
    );
    result = NULL;
    if norm_len == 0 {
        result = PyUnicode_FromOrdinal(i32(46));
    } else {
        result = PyUnicode_FromWideChar(norm_path, norm_len);
    }
    if result and jacpy_is_bytes(path.object) != 0 {
        encoded = PyUnicode_EncodeFSDefault(result);
        jacpy_release(result);
        result = encoded;
    }
    return result;
}

# --- times -------------------------------------------------------------------

# utime_t: the times os.utime() sets, or `now` for the current time.
obj:priv utime_t {
    has now: bool = False,
        atime_s: i64 = 0,
        atime_ns: i64 = 0,
        mtime_s: i64 = 0,
        mtime_ns: i64 = 0;
}

# UTIME_TO_TIMESPEC: the struct timespec[2] of `ut` in `memory`, or NULL for
# the current time.
def:priv utime_to_timespec(ut: utime_t, memory: ptr[timespec]) -> ptr[timespec] {
    if ut.now {
        return ptr[timespec]();
    }
    times = memory.view(2);
    times[0].tv_sec = ut.atime_s;
    times[0].tv_nsec = ut.atime_ns;
    times[1].tv_sec = ut.mtime_s;
    times[1].tv_nsec = ut.mtime_ns;
    return memory;
}

# Both targets have utimensat(), which utime_dir_fd() prefers to futimesat().
def:priv utime_dir_fd(
    ut: utime_t,
    memory: ptr[timespec],
    dir_fd: i32,
    path: ptr[u8],
    follow_symlinks: bool
) -> i32 {
    flags = i32(0) if follow_symlinks else i32(AT_SYMLINK_NOFOLLOW);
    return utimensat(dir_fd, path, utime_to_timespec(ut, memory), flags);
}

def:priv utime_fd(ut: utime_t, memory: ptr[timespec], fd: i32) -> i32 {
    return futimens(fd, utime_to_timespec(ut, memory));
}

def:priv utime_nofollow_symlinks(
    ut: utime_t, memory: ptr[timespec], path: ptr[u8]
) -> i32 {
    return utimensat(
        DEFAULT_DIR_FD, path, utime_to_timespec(ut, memory), i32(AT_SYMLINK_NOFOLLOW)
    );
}

def:priv utime_default(ut: utime_t, memory: ptr[timespec], path: ptr[u8]) -> i32 {
    return utimensat(DEFAULT_DIR_FD, path, utime_to_timespec(ut, memory), i32(0));
}

# split_py_long_to_s_and_ns(): divmod(py_long, 10**9) as a time_t and a long.
def:priv split_py_long_to_s_and_ns(
    module: ptr[PyObject], py_long: ptr[PyObject]
) -> (tuple[bool, i64, i64]) {
    divmod = PyNumber_Divmod(py_long, state_object(module, STATE_BILLION));
    if not divmod {
        return (False, 0, 0);
    }
    if jacpy_is_tuple(divmod) == 0 or PyTuple_Size(divmod) != 2 {
        PyErr_Format(
            PyExc_TypeError,
            "%.200s.__divmod__() must return a 2-tuple, not %.200s",
            _PyType_Name(Py_TYPE(py_long)),
            _PyType_Name(Py_TYPE(divmod))
        );
        jacpy_release(divmod);
        return (False, 0, 0);
    }
    seconds = _PyLong_AsTime_t(PyTuple_GetItem(divmod, 0));
    if seconds == -1 and PyErr_Occurred() {
        jacpy_release(divmod);
        return (False, 0, 0);
    }
    nanoseconds = PyLong_AsLong(PyTuple_GetItem(divmod, 1));
    if nanoseconds == -1 and PyErr_Occurred() {
        jacpy_release(divmod);
        return (False, 0, 0);
    }
    jacpy_release(divmod);
    return (True, seconds, nanoseconds);
}

def os_utime_impl(
    module: ptr[PyObject],
    path: path_t,
    times: ptr[PyObject],
    ns: ptr[PyObject],
    dir_fd: i32,
    follow_symlinks: bool
) -> ptr[PyObject] {
    ut = utime_t();
    if times != Py_None and ns {
        PyErr_SetString(
            PyExc_ValueError,
            "utime: you may specify either 'times' or 'ns' but not both"
        );
        return NULL;
    }
    if times != Py_None {
        if jacpy_is_exact_tuple(times) == 0 or PyTuple_Size(times) != 2 {
            PyErr_SetString(
                PyExc_TypeError,
                "utime: 'times' must be either a tuple of two ints or None"
            );
            return NULL;
        }
        ut.now = False;
        a_sec = i64(0);
        a_nsec = i64(0);
        m_sec = i64(0);
        m_nsec = i64(0);
        if _PyTime_ObjectToTimespec(
            PyTuple_GetItem(times, 0), &mut a_sec, &mut a_nsec, _PyTime_ROUND_FLOOR
        )
            == -1
            or _PyTime_ObjectToTimespec(
                PyTuple_GetItem(times, 1), &mut m_sec, &mut m_nsec, _PyTime_ROUND_FLOOR
            )
                == -1 {
            return NULL;
        }
        ut.atime_s = a_sec;
        ut.atime_ns = a_nsec;
        ut.mtime_s = m_sec;
        ut.mtime_ns = m_nsec;
    } elif ns {
        if jacpy_is_exact_tuple(ns) == 0 or PyTuple_Size(ns) != 2 {
            PyErr_SetString(PyExc_TypeError, "utime: 'ns' must be a tuple of two ints");
            return NULL;
        }
        ut.now = False;
        (ok, seconds, nanoseconds) = split_py_long_to_s_and_ns(
            module, PyTuple_GetItem(ns, 0)
        );
        if not ok {
            return NULL;
        }
        ut.atime_s = seconds;
        ut.atime_ns = nanoseconds;
        (ok, seconds, nanoseconds) = split_py_long_to_s_and_ns(
            module, PyTuple_GetItem(ns, 1)
        );
        if not ok {
            return NULL;
        }
        ut.mtime_s = seconds;
        ut.mtime_ns = nanoseconds;
    } else {
        # times and ns are both None/unspecified: use "now".
        ut.now = True;
    }
    have_nofollow_symlinks = HAVE_UTIMENSAT or HAVE_LUTIMES;
    if not have_nofollow_symlinks {
        if follow_symlinks_specified("utime", follow_symlinks) {
            return NULL;
        }
    }
    if path_and_dir_fd_invalid("utime", path, dir_fd)
        or dir_fd_and_fd_invalid("utime", dir_fd, path.fd)
        or fd_and_follow_symlinks_invalid("utime", path.fd, follow_symlinks) {
        return NULL;
    }
    if not HAVE_UTIMENSAT and dir_fd != DEFAULT_DIR_FD and not follow_symlinks {
        PyErr_SetString(
            PyExc_ValueError,
            "utime: cannot use dir_fd and follow_symlinks together on this platform"
        );
        return NULL;
    }
    if PySys_Audit(
        "os.utime", "OOOi", path.object, times, ns or Py_None, audit_dir_fd(dir_fd)
    )
        < 0 {
        return NULL;
    }
    # The struct timespec ts[2] the macros fill on the C stack.
    memory = ptr[timespec](PyMem_Calloc(2, TIMESPEC_SIZE));
    if not memory {
        return PyErr_NoMemory();
    }
    fd = path.fd;
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = i32(0);
    if have_nofollow_symlinks and not follow_symlinks and dir_fd == DEFAULT_DIR_FD {
        result = utime_nofollow_symlinks(ut, memory, narrow);
    } elif (HAVE_FUTIMESAT or HAVE_UTIMENSAT)
        and (dir_fd != DEFAULT_DIR_FD or not follow_symlinks) {
        result = utime_dir_fd(ut, memory, dir_fd, narrow, follow_symlinks);
    } elif (HAVE_FUTIMES or HAVE_FUTIMENS) and fd != -1 {
        result = utime_fd(ut, memory, fd);
    } else {
        result = utime_default(ut, memory, narrow);
    }
    PyEval_RestoreThread(thread);
    PyMem_Free(ptr(memory));
    if PLATFORM == "darwin" and HAVE_UTIMENSAT {
        # See utime_dir_fd.
        if result == -1 and jacpy_errno() == ENOSYS {
            argument_unavailable_error("", "dir_fd");
            return NULL;
        }
    }
    if result < 0 {
        path_error(path);
        return NULL;
    }
    return none();
}

# --- fifos and device nodes --------------------------------------------------

def os_mkfifo_impl(
    module: ptr[PyObject], path: path_t, mode: i32, dir_fd: i32
) -> ptr[PyObject] {
    async_err = False;
    mkfifoat_unavailable = False;
    narrow = path.narrow;
    result = i32(0);
    while True {
        thread = PyEval_SaveThread();
        if HAVE_MKFIFOAT and dir_fd != DEFAULT_DIR_FD {
            if mkfifoat_available() {
                result = mkfifoat_call(dir_fd, narrow, mode_t(mode));
            } else {
                mkfifoat_unavailable = True;
                result = i32(0);
            }
        } else {
            result = mkfifo(narrow, mode_t(mode));
        }
        PyEval_RestoreThread(thread);
        if result != 0 and jacpy_errno() == EINTR {
            if PyErr_CheckSignals() != 0 {
                async_err = True;
                break;
            }
            continue;
        }
        break;
    }
    if mkfifoat_unavailable {
        argument_unavailable_error("", "dir_fd");
        return NULL;
    }
    if result != 0 {
        return NULL if async_err else posix_error();
    }
    return none();
}

def os_mknod_impl(
    module: ptr[PyObject], path: path_t, mode: i32, device: u64, dir_fd: i32
) -> ptr[PyObject] {
    async_err = False;
    mknodat_unavailable = False;
    narrow = path.narrow;
    result = i32(0);
    while True {
        thread = PyEval_SaveThread();
        if HAVE_MKNODAT and dir_fd != DEFAULT_DIR_FD {
            if mknodat_available() {
                result = mknodat_call(dir_fd, narrow, mode_t(mode), device);
            } else {
                mknodat_unavailable = True;
                result = i32(0);
            }
        } else {
            result = mknod_call(narrow, mode_t(mode), device);
        }
        PyEval_RestoreThread(thread);
        if result != 0 and jacpy_errno() == EINTR {
            if PyErr_CheckSignals() != 0 {
                async_err = True;
                break;
            }
            continue;
        }
        break;
    }
    if mknodat_unavailable {
        argument_unavailable_error("", "dir_fd");
        return NULL;
    }
    if result != 0 {
        return NULL if async_err else posix_error();
    }
    return none();
}

def:priv major_minor_conv(value: u32) -> ptr[PyObject] {
    if value == u32.wrap(NODEV) {
        return PyLong_FromLong(NODEV);
    }
    return PyLong_FromUnsignedLong(u64(value));
}

# (dev_t)(unsigned int)value == value, NODEV passing.
def:priv major_minor_check(value: u64) -> bool {
    if dev_value(value) == NODEV {
        return True;
    }
    if DEV_T_SIGNED_32 {
        return True;
    }
    return u64(u32.wrap(value)) == value;
}

def os_major_impl(module: ptr[PyObject], device: u64) -> ptr[PyObject] {
    return major_minor_conv(dev_major(device));
}

def os_minor_impl(module: ptr[PyObject], device: u64) -> ptr[PyObject] {
    return major_minor_conv(dev_minor(device));
}

def os_makedev_impl(module: ptr[PyObject], major: u64, minor: u64) -> u64 {
    if not major_minor_check(major) or not major_minor_check(minor) {
        PyErr_SetString(
            PyExc_OverflowError, "Python int too large to convert to C unsigned int"
        );
        return u64.wrap(-1);
    }
    return dev_makedev(major, minor);
}

# --- truncation and allocation -----------------------------------------------

def os_ftruncate_impl(module: ptr[PyObject], fd: i32, length: i64) -> ptr[PyObject] {
    if PySys_Audit("os.truncate", "in", fd, length) < 0 {
        return NULL;
    }
    async_err = False;
    result = i32(0);
    while True {
        thread = PyEval_SaveThread();
        result = ftruncate(fd, length);
        PyEval_RestoreThread(thread);
        if result != 0 and jacpy_errno() == EINTR {
            if PyErr_CheckSignals() != 0 {
                async_err = True;
                break;
            }
            continue;
        }
        break;
    }
    if result != 0 {
        return NULL if async_err else posix_error();
    }
    return none();
}

def os_truncate_impl(
    module: ptr[PyObject], path: path_t, length: i64
) -> ptr[PyObject] {
    if path.fd != -1 {
        return os_ftruncate_impl(module, path.fd, length);
    }
    if PySys_Audit("os.truncate", "On", path.object, length) < 0 {
        return NULL;
    }
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = truncate(narrow, length);
    PyEval_RestoreThread(thread);
    if result < 0 {
        return posix_path_error(path);
    }
    return none();
}

def os_posix_fallocate_impl(
    module: ptr[PyObject], fd: i32, offset: i64, length: i64
) -> ptr[PyObject] {
    async_err = False;
    result = i32(0);
    while True {
        thread = PyEval_SaveThread();
        result = posix_fallocate_call(fd, offset, length);
        PyEval_RestoreThread(thread);
        if result == EINTR {
            if PyErr_CheckSignals() != 0 {
                async_err = True;
                break;
            }
            continue;
        }
        break;
    }
    if result == 0 {
        return none();
    }
    if async_err {
        return NULL;
    }
    jacpy_set_errno(i64(result));
    return posix_error();
}

def os_posix_fadvise_impl(
    module: ptr[PyObject], fd: i32, offset: i64, length: i64, advice: i32
) -> ptr[PyObject] {
    async_err = False;
    result = i32(0);
    while True {
        thread = PyEval_SaveThread();
        result = posix_fadvise_call(fd, offset, length, advice);
        PyEval_RestoreThread(thread);
        if result == EINTR {
            if PyErr_CheckSignals() != 0 {
                async_err = True;
                break;
            }
            continue;
        }
        break;
    }
    if result == 0 {
        return none();
    }
    if async_err {
        return NULL;
    }
    jacpy_set_errno(i64(result));
    return posix_error();
}

def os_lockf_impl(
    module: ptr[PyObject], fd: i32, command: i32, length: i64
) -> ptr[PyObject] {
    if PySys_Audit("os.lockf", "iiL", fd, command, length) < 0 {
        return NULL;
    }
    thread = PyEval_SaveThread();
    result = lockf(fd, command, length);
    PyEval_RestoreThread(thread);
    if result < 0 {
        return posix_error();
    }
    return none();
}

# --- path configuration ------------------------------------------------------

def os_fpathconf_impl(module: ptr[PyObject], fd: i32, name: i32) -> i64 {
    jacpy_set_errno(0);
    limit = fpathconf(fd, name);
    if limit == -1 and jacpy_errno() != 0 {
        posix_error();
    }
    return limit;
}

def os_pathconf_impl(module: ptr[PyObject], path: path_t, name: i32) -> i64 {
    jacpy_set_errno(0);
    limit = i64(0);
    if HAVE_FPATHCONF and path.is_fd {
        limit = fpathconf(path.fd, name);
    } else {
        limit = pathconf(path.narrow, name);
    }
    if limit == -1 and jacpy_errno() != 0 {
        if jacpy_errno() == EINVAL {
            # Could be a path or name problem.
            posix_error();
        } else {
            path_error(path);
        }
    }
    return limit;
}

# --- extended attributes -----------------------------------------------------

def os_getxattr_impl(
    module: ptr[PyObject], path: path_t, attribute: path_t, follow_symlinks: bool
) -> ptr[PyObject] {
    if fd_and_follow_symlinks_invalid("getxattr", path.fd, follow_symlinks) {
        return NULL;
    }
    if PySys_Audit("os.getxattr", "OO", path.object, attribute.object) < 0 {
        return NULL;
    }
    buffer_sizes: list[i64] = [128, XATTR_SIZE_MAX, 0];
    fd = path.fd;
    narrow = path.narrow;
    name = attribute.narrow;
    buffer = NULL;
    index = 0;
    while True {
        buffer_size = buffer_sizes[index];
        index += 1;
        if buffer_size == 0 {
            path_error(path);
            return NULL;
        }
        buffer = PyBytes_FromStringAndSize(ptr[u8](), buffer_size);
        if not buffer {
            return NULL;
        }
        data = ptr(PyBytes_AsString(buffer));
        thread = PyEval_SaveThread();
        result = xattr_get(fd, narrow, follow_symlinks, name, data, u64(buffer_size));
        PyEval_RestoreThread(thread);
        if result < 0 {
            if jacpy_errno() == ERANGE {
                jacpy_release(buffer);
                continue;
            }
            path_error(path);
            jacpy_release(buffer);
            return NULL;
        }
        if result != buffer_size {
            # Can only shrink.
            _PyBytes_Resize(&mut buffer, result);
        }
        break;
    }
    return buffer;
}

def os_setxattr_impl(
    module: ptr[PyObject],
    path: path_t,
    attribute: path_t,
    value: BufferArgument,
    flags: i32,
    follow_symlinks: bool
) -> ptr[PyObject] {
    if fd_and_follow_symlinks_invalid("setxattr", path.fd, follow_symlinks) {
        return NULL;
    }
    if PySys_Audit(
        "os.setxattr",
        "OOy#i",
        path.object,
        attribute.object,
        value.address(),
        value.size(),
        flags
    )
        < 0 {
        return NULL;
    }
    fd = path.fd;
    narrow = path.narrow;
    name = attribute.narrow;
    data = value.address();
    size = u64(value.size());
    thread = PyEval_SaveThread();
    result = xattr_set(fd, narrow, follow_symlinks, name, data, size, flags);
    PyEval_RestoreThread(thread);
    if result != 0 {
        path_error(path);
        return NULL;
    }
    return none();
}

def os_removexattr_impl(
    module: ptr[PyObject], path: path_t, attribute: path_t, follow_symlinks: bool
) -> ptr[PyObject] {
    if fd_and_follow_symlinks_invalid("removexattr", path.fd, follow_symlinks) {
        return NULL;
    }
    if PySys_Audit("os.removexattr", "OO", path.object, attribute.object) < 0 {
        return NULL;
    }
    fd = path.fd;
    narrow = path.narrow;
    name = attribute.narrow;
    thread = PyEval_SaveThread();
    result = xattr_remove(fd, narrow, follow_symlinks, name);
    PyEval_RestoreThread(thread);
    if result != 0 {
        return path_error(path);
    }
    return none();
}

def os_listxattr_impl(
    module: ptr[PyObject], path: path_t, follow_symlinks: bool
) -> ptr[PyObject] {
    if fd_and_follow_symlinks_invalid("listxattr", path.fd, follow_symlinks) {
        return NULL;
    }
    if PySys_Audit("os.listxattr", "(O)", path.object or Py_None) < 0 {
        return NULL;
    }
    # name = path->narrow ? path->narrow : "."
    current = ptr[u8]();
    name = path.narrow;
    if not name {
        current = ptr[u8](PyMem_Malloc(2));
        if not current {
            return PyErr_NoMemory();
        }
        current.view(2)[0] = u8(46);
        current.view(2)[1] = u8(0);
        name = current;
    }
    buffer_sizes: list[i64] = [256, XATTR_LIST_MAX, 0];
    fd = path.fd;
    result = NULL;
    buffer = ptr[u8]();
    index = 0;
    while True {
        buffer_size = buffer_sizes[index];
        index += 1;
        if buffer_size == 0 {
            # ERANGE
            path_error(path);
            break;
        }
        buffer = ptr[u8](PyMem_Malloc(u64(buffer_size)));
        if not buffer {
            PyErr_NoMemory();
            break;
        }
        thread = PyEval_SaveThread();
        length = xattr_list(fd, name, follow_symlinks, buffer, u64(buffer_size));
        PyEval_RestoreThread(thread);
        if length < 0 {
            if jacpy_errno() == ERANGE {
                PyMem_Free(ptr(buffer));
                buffer = ptr[u8]();
                continue;
            }
            path_error(path);
            break;
        }
        result = PyList_New(0);
        if not result {
            break;
        }
        start = i64(0);
        trace = i64(0);
        while trace != length {
            if (buffer + trace).view(1)[0] == u8(0) {
                attribute = PyUnicode_DecodeFSDefaultAndSize(
                    buffer + start, trace - start
                );
                if not attribute {
                    jacpy_release(result);
                    result = NULL;
                    break;
                }
                error = PyList_Append(result, attribute);
                jacpy_release(attribute);
                if error != 0 {
                    jacpy_release(result);
                    result = NULL;
                    break;
                }
                start = trace + 1;
            }
            trace += 1;
        }
        break;
    }
    if buffer {
        PyMem_Free(ptr(buffer));
    }
    PyMem_Free(ptr(current));
    return result;
}
