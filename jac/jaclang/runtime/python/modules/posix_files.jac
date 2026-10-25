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

def posix_files_exec(module: ptr[PyObject]) -> bool;

def:priv mode_t(mode: i32) -> u32;

def:priv audit_dir_fd(dir_fd: i32) -> i32;

def:priv none -> ptr[PyObject];

def os_access_impl(
    module: ptr[PyObject],
    path: path_t,
    mode: i32,
    dir_fd: i32,
    effective_ids: bool,
    follow_symlinks: bool
) -> i32;

def os_chdir_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject];

def os_fchdir_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def:priv posix_getcwd(use_bytes: bool) -> ptr[PyObject];

def os_getcwd_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_getcwdb_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_chmod_impl(
    module: ptr[PyObject], path: path_t, mode: i32, dir_fd: i32, follow_symlinks: bool
) -> ptr[PyObject];

def os_fchmod_impl(module: ptr[PyObject], fd: i32, mode: i32) -> ptr[PyObject];

def os_lchmod_impl(module: ptr[PyObject], path: path_t, mode: i32) -> ptr[PyObject];

def os_chflags_impl(
    module: ptr[PyObject], path: path_t, flags: u64, follow_symlinks: bool
) -> ptr[PyObject];

def os_lchflags_impl(module: ptr[PyObject], path: path_t, flags: u64) -> ptr[PyObject];

def os_chroot_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject];

def os_fsync_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_sync_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_fdatasync_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_chown_impl(
    module: ptr[PyObject],
    path: path_t,
    uid: u32,
    gid: u32,
    dir_fd: i32,
    follow_symlinks: bool
) -> ptr[PyObject];

def os_fchown_impl(
    module: ptr[PyObject], fd: i32, uid: u32, gid: u32
) -> ptr[PyObject];

def os_lchown_impl(
    module: ptr[PyObject], path: path_t, uid: u32, gid: u32
) -> ptr[PyObject];

def os_link_impl(
    module: ptr[PyObject],
    src: path_t,
    dst: path_t,
    src_dir_fd: i32,
    dst_dir_fd: i32,
    follow_symlinks: i32
) -> ptr[PyObject];

def os_mkdir_impl(
    module: ptr[PyObject], path: path_t, mode: i32, dir_fd: i32
) -> ptr[PyObject];

def internal_rename(
    src: path_t, dst: path_t, src_dir_fd: i32, dst_dir_fd: i32, is_replace: bool
) -> ptr[PyObject];

def os_rename_impl(
    module: ptr[PyObject], src: path_t, dst: path_t, src_dir_fd: i32, dst_dir_fd: i32
) -> ptr[PyObject];

def os_replace_impl(
    module: ptr[PyObject], src: path_t, dst: path_t, src_dir_fd: i32, dst_dir_fd: i32
) -> ptr[PyObject];

def os_rmdir_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject];

def os_umask_impl(module: ptr[PyObject], mask: i32) -> ptr[PyObject];

def os_unlink_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject];

def os_remove_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject];

def os_readlink_impl(
    module: ptr[PyObject], path: path_t, dir_fd: i32
) -> ptr[PyObject];

def os_symlink_impl(
    module: ptr[PyObject],
    src: path_t,
    dst: path_t,
    target_is_directory: bool,
    dir_fd: i32
) -> ptr[PyObject];

def os__path_splitroot_ex_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject];

def os__path_normpath_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject];

obj:priv utime_t {
    has now: bool = False,
        atime_s: i64 = 0,
        atime_ns: i64 = 0,
        mtime_s: i64 = 0,
        mtime_ns: i64 = 0;
}

def:priv utime_to_timespec(ut: utime_t, memory: ptr[timespec]) -> ptr[timespec];

def:priv utime_dir_fd(
    ut: utime_t,
    memory: ptr[timespec],
    dir_fd: i32,
    path: ptr[u8],
    follow_symlinks: bool
) -> i32;

def:priv utime_fd(ut: utime_t, memory: ptr[timespec], fd: i32) -> i32;

def:priv utime_nofollow_symlinks(
    ut: utime_t, memory: ptr[timespec], path: ptr[u8]
) -> i32;

def:priv utime_default(ut: utime_t, memory: ptr[timespec], path: ptr[u8]) -> i32;

def:priv split_py_long_to_s_and_ns(
    module: ptr[PyObject], py_long: ptr[PyObject]
) -> (tuple[bool, i64, i64]);

def os_utime_impl(
    module: ptr[PyObject],
    path: path_t,
    times: ptr[PyObject],
    ns: ptr[PyObject],
    dir_fd: i32,
    follow_symlinks: bool
) -> ptr[PyObject];

def os_mkfifo_impl(
    module: ptr[PyObject], path: path_t, mode: i32, dir_fd: i32
) -> ptr[PyObject];

def os_mknod_impl(
    module: ptr[PyObject], path: path_t, mode: i32, device: u64, dir_fd: i32
) -> ptr[PyObject];

def:priv major_minor_conv(value: u32) -> ptr[PyObject];

def:priv major_minor_check(value: u64) -> bool;

def os_major_impl(module: ptr[PyObject], device: u64) -> ptr[PyObject];

def os_minor_impl(module: ptr[PyObject], device: u64) -> ptr[PyObject];

def os_makedev_impl(module: ptr[PyObject], major: u64, minor: u64) -> u64;

def os_ftruncate_impl(module: ptr[PyObject], fd: i32, length: i64) -> ptr[PyObject];

def os_truncate_impl(
    module: ptr[PyObject], path: path_t, length: i64
) -> ptr[PyObject];

def os_posix_fallocate_impl(
    module: ptr[PyObject], fd: i32, offset: i64, length: i64
) -> ptr[PyObject];

def os_posix_fadvise_impl(
    module: ptr[PyObject], fd: i32, offset: i64, length: i64, advice: i32
) -> ptr[PyObject];

def os_lockf_impl(
    module: ptr[PyObject], fd: i32, command: i32, length: i64
) -> ptr[PyObject];

def os_fpathconf_impl(module: ptr[PyObject], fd: i32, name: i32) -> i64;

def os_pathconf_impl(module: ptr[PyObject], path: path_t, name: i32) -> i64;

def os_getxattr_impl(
    module: ptr[PyObject], path: path_t, attribute: path_t, follow_symlinks: bool
) -> ptr[PyObject];

def os_setxattr_impl(
    module: ptr[PyObject],
    path: path_t,
    attribute: path_t,
    value: BufferArgument,
    flags: i32,
    follow_symlinks: bool
) -> ptr[PyObject];

def os_removexattr_impl(
    module: ptr[PyObject], path: path_t, attribute: path_t, follow_symlinks: bool
) -> ptr[PyObject];

def os_listxattr_impl(
    module: ptr[PyObject], path: path_t, follow_symlinks: bool
) -> ptr[PyObject];

impl posix_files_exec(module: ptr[PyObject]) -> bool {
    return True;
}

impl mode_t(mode: i32) -> u32 {
    return u32.wrap(mode) & MODE_T_MASK;
}

impl audit_dir_fd(dir_fd: i32) -> i32 {
    return i32(-1) if dir_fd == DEFAULT_DIR_FD else dir_fd;
}

impl none -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}

impl os_access_impl(
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

impl os_chdir_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.chdir"), ptr[u8]("(O)"), path.object) < 0 {
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

impl os_fchdir_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.chdir"), ptr[u8]("(i)"), fd) < 0 {
        return NULL;
    }
    return posix_fildes_fd(fd, 2);
}

impl posix_getcwd(use_bytes: bool) -> ptr[PyObject] {
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
        jacpy_set_errno(ENOENT);
        path_object_error(result);
        jacpy_release(result);
        PyMem_RawFree(ptr(buffer));
        return NULL;
    }
    PyMem_RawFree(ptr(buffer));
    return result;
}

impl os_getcwd_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return posix_getcwd(False);
}

impl os_getcwdb_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return posix_getcwd(True);
}

impl os_chmod_impl(
    module: ptr[PyObject], path: path_t, mode: i32, dir_fd: i32, follow_symlinks: bool
) -> ptr[PyObject] {
    fchmodat_nofollow_unsupported = False;
    if not (HAVE_FCHMODAT or HAVE_LCHMOD) {
        if follow_symlinks_specified("chmod", follow_symlinks) {
            return NULL;
        }
    }
    if PySys_Audit(
        ptr[u8]("os.chmod"), ptr[u8]("Oii"), path.object, mode, audit_dir_fd(dir_fd)
    )
        < 0 {
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

impl os_fchmod_impl(module: ptr[PyObject], fd: i32, mode: i32) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.chmod"), ptr[u8]("iii"), fd, mode, i32(-1)) < 0 {
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

impl os_lchmod_impl(module: ptr[PyObject], path: path_t, mode: i32) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.chmod"), ptr[u8]("Oii"), path.object, mode, i32(-1)) < 0 {
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

impl os_chflags_impl(
    module: ptr[PyObject], path: path_t, flags: u64, follow_symlinks: bool
) -> ptr[PyObject] {
    if not HAVE_LCHFLAGS {
        if follow_symlinks_specified("chflags", follow_symlinks) {
            return NULL;
        }
    }
    if PySys_Audit(ptr[u8]("os.chflags"), ptr[u8]("Ok"), path.object, flags) < 0 {
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

impl os_lchflags_impl(
    module: ptr[PyObject], path: path_t, flags: u64
) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.chflags"), ptr[u8]("Ok"), path.object, flags) < 0 {
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

impl os_chroot_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
    narrow = path.narrow;
    thread = PyEval_SaveThread();
    result = chroot(narrow);
    PyEval_RestoreThread(thread);
    if result < 0 {
        return path_error(path);
    }
    return none();
}

impl os_fsync_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    return posix_fildes_fd(fd, 0);
}

impl os_sync_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    sync();
    PyEval_RestoreThread(thread);
    return none();
}

impl os_fdatasync_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    return posix_fildes_fd(fd, 1);
}

impl os_chown_impl(
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
    if PySys_Audit(
        ptr[u8]("os.chown"),
        ptr[u8]("OIIi"),
        path.object,
        uid,
        gid,
        audit_dir_fd(dir_fd)
    )
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

impl os_fchown_impl(
    module: ptr[PyObject], fd: i32, uid: u32, gid: u32
) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.chown"), ptr[u8]("iIIi"), fd, uid, gid, i32(-1)) < 0 {
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

impl os_lchown_impl(
    module: ptr[PyObject], path: path_t, uid: u32, gid: u32
) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.chown"), ptr[u8]("OIIi"), path.object, uid, gid, i32(-1))
        < 0 {
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

impl os_link_impl(
    module: ptr[PyObject],
    src: path_t,
    dst: path_t,
    src_dir_fd: i32,
    dst_dir_fd: i32,
    follow_symlinks: i32
) -> ptr[PyObject] {
    if HAVE_LINKAT {
        if follow_symlinks < 0 {
            follow_symlinks = i32(1);
        }
    } else {
        if src_dir_fd != DEFAULT_DIR_FD or dst_dir_fd != DEFAULT_DIR_FD {
            argument_unavailable_error("link", "src_dir_fd and dst_dir_fd");
            return NULL;
        }
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
        ptr[u8]("os.link"),
        ptr[u8]("OOii"),
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

impl os_mkdir_impl(
    module: ptr[PyObject], path: path_t, mode: i32, dir_fd: i32
) -> ptr[PyObject] {
    if PySys_Audit(
        ptr[u8]("os.mkdir"), ptr[u8]("Oii"), path.object, mode, audit_dir_fd(dir_fd)
    )
        < 0 {
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

impl internal_rename(
    src: path_t, dst: path_t, src_dir_fd: i32, dst_dir_fd: i32, is_replace: bool
) -> ptr[PyObject] {
    function_name = "replace" if is_replace else "rename";
    dir_fd_specified = src_dir_fd != DEFAULT_DIR_FD or dst_dir_fd != DEFAULT_DIR_FD;
    if not HAVE_RENAMEAT and dir_fd_specified {
        argument_unavailable_error(function_name, "src_dir_fd and dst_dir_fd");
        return NULL;
    }
    if PySys_Audit(
        ptr[u8]("os.rename"),
        ptr[u8]("OOii"),
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

impl os_rename_impl(
    module: ptr[PyObject], src: path_t, dst: path_t, src_dir_fd: i32, dst_dir_fd: i32
) -> ptr[PyObject] {
    return internal_rename(src, dst, src_dir_fd, dst_dir_fd, False);
}

impl os_replace_impl(
    module: ptr[PyObject], src: path_t, dst: path_t, src_dir_fd: i32, dst_dir_fd: i32
) -> ptr[PyObject] {
    return internal_rename(src, dst, src_dir_fd, dst_dir_fd, True);
}

impl os_rmdir_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.rmdir"), ptr[u8]("Oi"), path.object, audit_dir_fd(dir_fd)) < 0 {
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

impl os_umask_impl(module: ptr[PyObject], mask: i32) -> ptr[PyObject] {
    previous = i32.wrap(umask_call(mode_t(mask)) & MODE_T_MASK);
    if previous < 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(previous));
}

impl os_unlink_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.remove"), ptr[u8]("Oi"), path.object, audit_dir_fd(dir_fd)) < 0 {
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

impl os_remove_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject] {
    return os_unlink_impl(module, path, dir_fd);
}

impl os_readlink_impl(
    module: ptr[PyObject], path: path_t, dir_fd: i32
) -> ptr[PyObject] {
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

impl os_symlink_impl(
    module: ptr[PyObject],
    src: path_t,
    dst: path_t,
    target_is_directory: bool,
    dir_fd: i32
) -> ptr[PyObject] {
    if PySys_Audit(
        ptr[u8]("os.symlink"),
        ptr[u8]("OOi"),
        src.object,
        dst.object,
        audit_dir_fd(dir_fd)
    )
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

impl os__path_splitroot_ex_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
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

impl os__path_normpath_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
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

impl utime_to_timespec(ut: utime_t, memory: ptr[timespec]) -> ptr[timespec] {
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

impl utime_dir_fd(
    ut: utime_t,
    memory: ptr[timespec],
    dir_fd: i32,
    path: ptr[u8],
    follow_symlinks: bool
) -> i32 {
    flags = i32(0) if follow_symlinks else i32(AT_SYMLINK_NOFOLLOW);
    return utimensat(dir_fd, path, utime_to_timespec(ut, memory), flags);
}

impl utime_fd(ut: utime_t, memory: ptr[timespec], fd: i32) -> i32 {
    return futimens(fd, utime_to_timespec(ut, memory));
}

impl utime_nofollow_symlinks(ut: utime_t, memory: ptr[timespec], path: ptr[u8]) -> i32 {
    return utimensat(
        DEFAULT_DIR_FD, path, utime_to_timespec(ut, memory), i32(AT_SYMLINK_NOFOLLOW)
    );
}

impl utime_default(ut: utime_t, memory: ptr[timespec], path: ptr[u8]) -> i32 {
    return utimensat(DEFAULT_DIR_FD, path, utime_to_timespec(ut, memory), i32(0));
}

impl split_py_long_to_s_and_ns(
    module: ptr[PyObject], py_long: ptr[PyObject]
) -> (tuple[bool, i64, i64]) {
    divmod = PyNumber_Divmod(py_long, state_object(module, STATE_BILLION));
    if not divmod {
        return (False, 0, 0);
    }
    if jacpy_is_tuple(divmod) == 0 or PyTuple_Size(divmod) != 2 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%.200s.__divmod__() must return a 2-tuple, not %.200s"),
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

impl os_utime_impl(
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
            ptr[u8]("utime: you may specify either 'times' or 'ns' but not both")
        );
        return NULL;
    }
    if times != Py_None {
        if jacpy_is_exact_tuple(times) == 0 or PyTuple_Size(times) != 2 {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8]("utime: 'times' must be either a tuple of two ints or None")
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
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("utime: 'ns' must be a tuple of two ints")
            );
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
            ptr[u8](
                "utime: cannot use dir_fd and follow_symlinks together on this platform"
            )
        );
        return NULL;
    }
    if PySys_Audit(
        ptr[u8]("os.utime"),
        ptr[u8]("OOOi"),
        path.object,
        times,
        ns or Py_None,
        audit_dir_fd(dir_fd)
    )
        < 0 {
        return NULL;
    }

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

impl os_mkfifo_impl(
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

impl os_mknod_impl(
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

impl major_minor_conv(value: u32) -> ptr[PyObject] {
    if value == u32.wrap(NODEV) {
        return PyLong_FromLong(NODEV);
    }
    return PyLong_FromUnsignedLong(u64(value));
}

impl major_minor_check(value: u64) -> bool {
    if dev_value(value) == NODEV {
        return True;
    }
    if DEV_T_SIGNED_32 {
        return True;
    }
    return u64(u32.wrap(value)) == value;
}

impl os_major_impl(module: ptr[PyObject], device: u64) -> ptr[PyObject] {
    return major_minor_conv(dev_major(device));
}

impl os_minor_impl(module: ptr[PyObject], device: u64) -> ptr[PyObject] {
    return major_minor_conv(dev_minor(device));
}

impl os_makedev_impl(module: ptr[PyObject], major: u64, minor: u64) -> u64 {
    if not major_minor_check(major) or not major_minor_check(minor) {
        PyErr_SetString(
            PyExc_OverflowError,
            ptr[u8]("Python int too large to convert to C unsigned int")
        );
        return u64.wrap(-1);
    }
    return dev_makedev(major, minor);
}

impl os_ftruncate_impl(module: ptr[PyObject], fd: i32, length: i64) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.truncate"), ptr[u8]("in"), fd, length) < 0 {
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

impl os_truncate_impl(
    module: ptr[PyObject], path: path_t, length: i64
) -> ptr[PyObject] {
    if path.fd != -1 {
        return os_ftruncate_impl(module, path.fd, length);
    }
    if PySys_Audit(ptr[u8]("os.truncate"), ptr[u8]("On"), path.object, length) < 0 {
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

impl os_posix_fallocate_impl(
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

impl os_posix_fadvise_impl(
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

impl os_lockf_impl(
    module: ptr[PyObject], fd: i32, command: i32, length: i64
) -> ptr[PyObject] {
    if PySys_Audit(ptr[u8]("os.lockf"), ptr[u8]("iiL"), fd, command, length) < 0 {
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

impl os_fpathconf_impl(module: ptr[PyObject], fd: i32, name: i32) -> i64 {
    jacpy_set_errno(0);
    limit = fpathconf(fd, name);
    if limit == -1 and jacpy_errno() != 0 {
        posix_error();
    }
    return limit;
}

impl os_pathconf_impl(module: ptr[PyObject], path: path_t, name: i32) -> i64 {
    jacpy_set_errno(0);
    limit = i64(0);
    if HAVE_FPATHCONF and path.is_fd {
        limit = fpathconf(path.fd, name);
    } else {
        limit = pathconf(path.narrow, name);
    }
    if limit == -1 and jacpy_errno() != 0 {
        if jacpy_errno() == EINVAL {
            posix_error();
        } else {
            path_error(path);
        }
    }
    return limit;
}

impl os_getxattr_impl(
    module: ptr[PyObject], path: path_t, attribute: path_t, follow_symlinks: bool
) -> ptr[PyObject] {
    if fd_and_follow_symlinks_invalid("getxattr", path.fd, follow_symlinks) {
        return NULL;
    }
    if PySys_Audit(ptr[u8]("os.getxattr"), ptr[u8]("OO"), path.object, attribute.object)
        < 0 {
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
            _PyBytes_Resize(&mut buffer, result);
        }
        break;
    }
    return buffer;
}

impl os_setxattr_impl(
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
        ptr[u8]("os.setxattr"),
        ptr[u8]("OOy#i"),
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

impl os_removexattr_impl(
    module: ptr[PyObject], path: path_t, attribute: path_t, follow_symlinks: bool
) -> ptr[PyObject] {
    if fd_and_follow_symlinks_invalid("removexattr", path.fd, follow_symlinks) {
        return NULL;
    }
    if PySys_Audit(
        ptr[u8]("os.removexattr"), ptr[u8]("OO"), path.object, attribute.object
    )
        < 0 {
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

impl os_listxattr_impl(
    module: ptr[PyObject], path: path_t, follow_symlinks: bool
) -> ptr[PyObject] {
    if fd_and_follow_symlinks_invalid("listxattr", path.fd, follow_symlinks) {
        return NULL;
    }
    if PySys_Audit(ptr[u8]("os.listxattr"), ptr[u8]("(O)"), path.object or Py_None)
        < 0 {
        return NULL;
    }

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
