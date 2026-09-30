"""The posix stat area: stat/lstat/fstat and os.stat_result, statvfs and
os.statvfs_result, listdir, scandir and os.DirEntry.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
struct stat is the per-target `_Py_stat_struct` of stat_records.jac, filled
by the C stat helpers (macOS x86_64 binds the $INODE64 stat and directory
symbols); the fields only some targets have (st_flags, st_gen,
st_birthtime) and the statvfs record live in posix_stat_platform.<os>.jac.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_FromString,
    PyBytes_FromStringAndSize,
    PyErr_CheckSignals,
    PyErr_ExceptionMatches,
    PyErr_Clear,
    PyErr_Format,
    PyErr_FormatUnraisable,
    PyErr_GetRaisedException,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_ResourceWarning,
    PyErr_SetRaisedException,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_FileNotFoundError,
    PyExc_NotImplementedError,
    PyExc_TypeError,
    PyExc_Warning,
    PyFloat_FromDouble,
    PyList_Append,
    PyList_New,
    PyLong_AsLong,
    PyLong_FromLong,
    PyLong_FromLongLong,
    PyLong_FromUnsignedLong,
    PyLong_FromUnsignedLongLong,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawMalloc,
    PyNumber_Add,
    PyNumber_Multiply,
    PyObject,
    PyObject_CallFinalizerFromDealloc,
    PyObject_GetAttr,
    PyType_GetModule,
    PyUnicode_DecodeFSDefault,
    PyUnicode_DecodeFSDefaultAndSize,
    PyUnicode_FSConverter,
    PyUnicode_FromFormat,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    Py_XNewRef,
    _PyLong_FromTime_t,
    _Py_dup,
    jacpy_bytes_length,
    jacpy_closedir,
    jacpy_errno,
    jacpy_fdopendir,
    jacpy_fstat,
    jacpy_fstatat,
    jacpy_is_bytes,
    jacpy_lstat,
    jacpy_opendir,
    jacpy_readdir_entry,
    jacpy_release,
    jacpy_rewinddir,
    jacpy_set_errno,
    jacpy_stat,
    PyBytes_AsString
}
import from jaclang.runtime.python.layouts { PyTypeObject as TypeLayout }
import from jaclang.runtime.python.capi { audit_event, boundary_failure }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.bindings.members { MemberField, MemberType }
import from jaclang.runtime.python.bindings.module {
    add_state_owned,
    jacpy_binding_module_native_get
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    jacpy_binding_native_clear,
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_record,
    struct_sequence_type
}
import from jaclang.runtime.python.object_model.structseq {
    PyStructSequence_GetItem,
    PyStructSequence_New,
    PyStructSequence_SetItem
}
import from jaclang.runtime.python.modules.stat { S_IFDIR, S_IFLNK, S_IFMT, S_IFREG }
import from jaclang.runtime.python.modules.stat_records { _Py_stat_struct }
import from jaclang.runtime.python.modules.posix_constants {
    AT_SYMLINK_NOFOLLOW,
    DT_DIR,
    DT_LNK,
    DT_REG,
    DT_UNKNOWN,
    EINTR,
    HAVE_FDOPENDIR,
    HAVE_FSTATAT,
    HAVE_FSTATVFS
}
import from jaclang.runtime.python.modules.posix_core {
    DEFAULT_DIR_FD,
    PosixState,
    STATE_BILLION,
    STATE_DIR_ENTRY_TYPE,
    STATE_SCANDIR_ITERATOR_TYPE,
    STATE_STATVFS_RESULT_TYPE,
    STATE_STAT_RESULT_TYPE,
    STATE_ST_MODE,
    _PyLong_FromDev,
    _PyLong_FromGid,
    _PyLong_FromUid,
    argument_unavailable_error,
    dir_fd_and_fd_invalid,
    fd_and_follow_symlinks_invalid,
    interned,
    path_and_dir_fd_invalid,
    path_error,
    path_object_error,
    path_t,
    posix_error,
    posix_module,
    posix_state,
    state_object
}
import from jaclang.runtime.python.modules.posix_stat_platform {
    STATVFS_RECORD_SIZE,
    STAT_EXTRA_FIELDS,
    set_stat_extra,
    stat_blksize,
    stat_device,
    stat_mode,
    stat_nlink,
    stat_rdev,
    statvfs_fd,
    statvfs_path,
    statvfs_result
}
import from c { def strlen(text: ptr[u8]) -> u64;  def close(fd: i32) -> i32;  }

glob STAT_RESULT_DOC: str = "stat_result: Result from stat, fstat, or lstat.\n\nThis object may be accessed either as a tuple of\n  (mode, ino, dev, nlink, uid, gid, size, atime, mtime, ctime)\nor via the attributes st_mode, st_ino, st_dev, st_nlink, and so on.\n\nPosix/windows: If your platform supports st_blksize, st_blocks, st_rdev,\nor st_flags, they are available as attributes only.\n\nSee os.stat for more information.",
     STATVFS_RESULT_DOC: str = "statvfs_result: Result from statvfs or fstatvfs.\n\nThis object may be accessed either as a tuple of\n  (bsize, frsize, blocks, bfree, bavail, files, ffree, favail, flag, namemax),\nor via the attributes f_bsize, f_frsize, f_blocks, f_bfree, and so on.\n\nSee os.statvfs for more information.",
     # stat_result_fields: the three integer times are unnamed.
     STAT_RESULT_FIELDS: list[tuple[str, str]] = [
         ("st_mode", "protection bits"),
         ("st_ino", "inode"),
         ("st_dev", "device"),
         ("st_nlink", "number of hard links"),
         ("st_uid", "user ID of owner"),
         ("st_gid", "group ID of owner"),
         ("st_size", "total size, in bytes"),
         ("", "integer time of last access"),
         ("", "integer time of last modification"),
         ("", "integer time of last change"),
         ("st_atime", "time of last access"),
         ("st_mtime", "time of last modification"),
         ("st_ctime", "time of last change"),
         ("st_atime_ns", "time of last access in nanoseconds"),
         ("st_mtime_ns", "time of last modification in nanoseconds"),
         ("st_ctime_ns", "time of last change in nanoseconds"),
         ("st_blksize", "blocksize for filesystem I/O"),
         ("st_blocks", "number of blocks allocated"),
         ("st_rdev", "device type (if inode device)")
     ],
     STATVFS_RESULT_FIELDS: list[tuple[str, str]] = [
         ("f_bsize", ""),
         ("f_frsize", ""),
         ("f_blocks", ""),
         ("f_bfree", ""),
         ("f_bavail", ""),
         ("f_files", ""),
         ("f_ffree", ""),
         ("f_favail", ""),
         ("f_flag", ""),
         ("f_namemax", ""),
         ("f_fsid", "")
     ],
     ST_BLKSIZE_IDX: i64 = 16,
     ST_BLOCKS_IDX: i64 = 17,
     ST_RDEV_IDX: i64 = 18;

# --- os.stat_result --------------------------------------------------------

import from c {
    # A tp_new slot read from the struct sequence type, so it can be called.
    obj NewFunctionSlot {
        has call:
            Callable[
                [ptr[TypeLayout], ptr[PyObject], ptr[PyObject]],
                ptr[PyObject]
            ] = 0;
    }
}

# statresult_new(): the struct sequence tp_new, then an st_?time given as
# None takes the integer slot's value.
def statresult_new(
    type_object: ptr[TypeLayout], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    # ht_module is not set by PyStructSequence_NewType(), so the module is
    # looked up by name.
    module = posix_module();
    if not module {
        return NULL;
    }
    original = posix_state(module).statresult_new_orig;
    jacpy_release(module);
    cell = ptr[NewFunctionSlot](PyMem_Malloc(8));
    if not cell {
        return PyErr_NoMemory();
    }
    cell.view(1)[0].call = original;
    result = cell.view(1)[0].call(type_object, args, kwds);
    PyMem_Free(cell);
    if not result {
        return NULL;
    }
    for index in range(7, 10) {
        if PyStructSequence_GetItem(result, i64(index + 3)) == Py_None {
            PyStructSequence_SetItem(
                result,
                i64(index + 3),
                Py_NewRef(PyStructSequence_GetItem(result, i64(index)))
            );
        }
    }
    return result;
}

# fill_time(): the integer seconds, float seconds and integer nanoseconds of
# one timestamp at the given indices (negative to skip).
def:priv fill_time(
    module: ptr[PyObject],
    v: ptr[PyObject],
    s_index: i64,
    f_index: i64,
    ns_index: i64,
    sec: i64,
    nsec: u64
) -> bool {
    seconds = _PyLong_FromTime_t(sec);
    fractional = PyLong_FromUnsignedLong(nsec);
    if not seconds or not fractional {
        jacpy_release(seconds);
        jacpy_release(fractional);
        return False;
    }
    in_ns = PyNumber_Multiply(seconds, state_object(module, STATE_BILLION));
    total = PyNumber_Add(in_ns, fractional) if in_ns else NULL;
    float_seconds = PyFloat_FromDouble(f64(sec) + 1e-9 * f64(nsec)) if total else NULL;
    jacpy_release(fractional);
    jacpy_release(in_ns);
    if not float_seconds {
        jacpy_release(seconds);
        jacpy_release(total);
        return False;
    }
    if s_index >= 0 {
        PyStructSequence_SetItem(v, s_index, seconds);
    } else {
        jacpy_release(seconds);
    }
    if f_index >= 0 {
        PyStructSequence_SetItem(v, f_index, float_seconds);
    } else {
        jacpy_release(float_seconds);
    }
    if ns_index >= 0 {
        PyStructSequence_SetItem(v, ns_index, total);
    } else {
        jacpy_release(total);
    }
    return True;
}

# Store a new reference at `index`; False when `value` is NULL.
def set_stat_item(v: ptr[PyObject], index: i64, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    PyStructSequence_SetItem(v, index, value);
    return True;
}

# _pystat_fromstructstat(): pack a struct stat into os.stat_result.
def _pystat_fromstructstat(
    module: ptr[PyObject], st: _Py_stat_struct
) -> ptr[PyObject] {
    v = PyStructSequence_New(state_object(module, STATE_STAT_RESULT_TYPE));
    if not v {
        return NULL;
    }
    filled = set_stat_item(v, 0, PyLong_FromLong(stat_mode(st)))
        and set_stat_item(v, 1, PyLong_FromUnsignedLongLong(st.st_ino))
        and set_stat_item(v, 2, _PyLong_FromDev(stat_device(st)))
        and set_stat_item(v, 3, PyLong_FromLong(stat_nlink(st)))
        and set_stat_item(v, 4, _PyLong_FromUid(st.st_uid))
        and set_stat_item(v, 5, _PyLong_FromGid(st.st_gid))
        and set_stat_item(v, 6, PyLong_FromLongLong(st.st_size))
        and fill_time(module, v, 7, 10, 13, st.st_atime_sec, u64.wrap(st.st_atime_nsec))
        and fill_time(module, v, 8, 11, 14, st.st_mtime_sec, u64.wrap(st.st_mtime_nsec))
        and fill_time(module, v, 9, 12, 15, st.st_ctime_sec, u64.wrap(st.st_ctime_nsec))
        and set_stat_item(v, ST_BLKSIZE_IDX, PyLong_FromLong(stat_blksize(st)))
        and set_stat_item(v, ST_BLOCKS_IDX, PyLong_FromLong(st.st_blocks))
        and set_stat_item(v, ST_RDEV_IDX, _PyLong_FromDev(stat_rdev(st)))
        and set_stat_extra(v, ST_RDEV_IDX + 1, st);
    if not filled {
        jacpy_release(v);
        return NULL;
    }
    return v;
}

# --- stat, lstat, fstat ----------------------------------------------------

def:priv posix_do_stat(
    module: ptr[PyObject],
    function_name: str,
    path: path_t,
    dir_fd: i32,
    follow_symlinks: bool
) -> ptr[PyObject] {
    if path_and_dir_fd_invalid("stat", path, dir_fd)
        or dir_fd_and_fd_invalid("stat", dir_fd, path.fd)
        or fd_and_follow_symlinks_invalid("stat", path.fd, follow_symlinks) {
        return NULL;
    }
    st = _Py_stat_struct();
    fstatat_unavailable = False;
    result = i32(0);
    thread = PyEval_SaveThread();
    if path.fd != -1 {
        result = jacpy_fstat(path.fd, &mut st);
    } elif not follow_symlinks and dir_fd == DEFAULT_DIR_FD {
        result = jacpy_lstat(path.narrow, &mut st);
    } elif dir_fd != DEFAULT_DIR_FD or not follow_symlinks {
        if HAVE_FSTATAT {
            result = jacpy_fstatat(
                dir_fd,
                path.narrow,
                &mut st,
                i32(0) if follow_symlinks else i32(AT_SYMLINK_NOFOLLOW)
            );
        } else {
            fstatat_unavailable = True;
        }
    } else {
        result = jacpy_stat(path.narrow, &mut st);
    }
    PyEval_RestoreThread(thread);
    if fstatat_unavailable {
        argument_unavailable_error("stat", "dir_fd");
        return NULL;
    }
    if result != 0 {
        return path_error(path);
    }
    return _pystat_fromstructstat(module, st);
}

def os_stat_impl(
    module: ptr[PyObject], path: path_t, dir_fd: i32, follow_symlinks: bool
) -> ptr[PyObject] {
    return posix_do_stat(module, "stat", path, dir_fd, follow_symlinks);
}

def os_lstat_impl(module: ptr[PyObject], path: path_t, dir_fd: i32) -> ptr[PyObject] {
    return posix_do_stat(module, "lstat", path, dir_fd, False);
}

def os_fstat_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    st = _Py_stat_struct();
    while True {
        thread = PyEval_SaveThread();
        result = jacpy_fstat(fd, &mut st);
        PyEval_RestoreThread(thread);
        if result == 0 {
            return _pystat_fromstructstat(module, st);
        }
        if jacpy_errno() != EINTR {
            return posix_error();
        }
        if PyErr_CheckSignals() != 0 {
            return NULL;
        }
    }
}

# --- statvfs ---------------------------------------------------------------

def os_fstatvfs_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    record = PyMem_RawMalloc(u64(STATVFS_RECORD_SIZE));
    if not record {
        return PyErr_NoMemory();
    }
    while True {
        thread = PyEval_SaveThread();
        result = statvfs_fd(fd, record);
        PyEval_RestoreThread(thread);
        if result == 0 {
            value = statvfs_result(
                state_object(module, STATE_STATVFS_RESULT_TYPE), record
            );
            PyMem_Free(record);
            return value;
        }
        if jacpy_errno() != EINTR {
            PyMem_Free(record);
            return posix_error();
        }
        if PyErr_CheckSignals() != 0 {
            PyMem_Free(record);
            return NULL;
        }
    }
}

def os_statvfs_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
    record = PyMem_RawMalloc(u64(STATVFS_RECORD_SIZE));
    if not record {
        return PyErr_NoMemory();
    }
    thread = PyEval_SaveThread();
    result = statvfs_fd(path.fd, record)
        if path.fd != -1 and HAVE_FSTATVFS
        else statvfs_path(path.narrow, record);
    PyEval_RestoreThread(thread);
    if result != 0 {
        PyMem_Free(record);
        return path_error(path);
    }
    value = statvfs_result(state_object(module, STATE_STATVFS_RESULT_TYPE), record);
    PyMem_Free(record);
    return value;
}

# --- listdir ---------------------------------------------------------------

def:priv is_dot(name: ptr[u8], length: i64) -> bool {
    return name.view(1)[0] == u8(46)
        and (length == 1 or ((name + 1).view(1)[0] == u8(46) and length == 2));
}

def:priv close_directory(directory: ptr, rewind: bool) {
    thread = PyEval_SaveThread();
    if rewind {
        jacpy_rewinddir(directory);
    }
    jacpy_closedir(directory);
    PyEval_RestoreThread(thread);
}

# _posix_listdir()
def:priv posix_listdir(path: path_t) -> ptr[PyObject] {
    directory = ptr();
    fd = i32(-1);
    return_str = True;
    jacpy_set_errno(0);
    if bool(HAVE_FDOPENDIR) and path.fd != -1 {
        # closedir() closes the FD, so it is duplicated.
        fd = _Py_dup(path.fd);
        if fd == -1 {
            return NULL;
        }
        thread = PyEval_SaveThread();
        directory = jacpy_fdopendir(fd);
        PyEval_RestoreThread(thread);
    } else {
        name = ptr[u8]("");
        if path.narrow {
            name = path.narrow;
            # Only return bytes if a bytes object was given.
            return_str = jacpy_is_bytes(path.object) == 0;
        } else {
            name = ptr[u8](".");
        }
        thread = PyEval_SaveThread();
        directory = jacpy_opendir(name);
        PyEval_RestoreThread(thread);
    }
    if not directory {
        path_error(path);
        if fd != -1 {
            thread = PyEval_SaveThread();
            close(fd);
            PyEval_RestoreThread(thread);
        }
        return NULL;
    }
    names = PyList_New(0);
    if not names {
        close_directory(directory, fd > -1);
        return NULL;
    }
    while True {
        kind = i64(0);
        inode = u64(0);
        jacpy_set_errno(0);
        thread = PyEval_SaveThread();
        entry_name = jacpy_readdir_entry(directory, &mut kind, &mut inode);
        PyEval_RestoreThread(thread);
        if not entry_name {
            if jacpy_errno() != 0 {
                path_error(path);
                jacpy_release(names);
                names = NULL;
            }
            break;
        }
        length = i64(strlen(entry_name));
        if is_dot(entry_name, length) {
            continue;
        }
        item = PyUnicode_DecodeFSDefaultAndSize(entry_name, length)
            if return_str
            else PyBytes_FromStringAndSize(entry_name, length);
        if not item {
            jacpy_release(names);
            names = NULL;
            break;
        }
        status = PyList_Append(names, item);
        jacpy_release(item);
        if status != 0 {
            jacpy_release(names);
            names = NULL;
            break;
        }
    }
    close_directory(directory, fd > -1);
    return names;
}

def os_listdir_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
    if not audit_event("os.listdir", [Py_NewRef(path.object or Py_None)]) {
        return NULL;
    }
    return posix_listdir(path);
}

# --- os.DirEntry -----------------------------------------------------------

import from c {
    # DirEntry's fields after the object header.
    obj DirEntryRecord {
        has name: ptr[PyObject] = ptr[PyObject](),
            path: ptr[PyObject] = ptr[PyObject](),
            stat: ptr[PyObject] = ptr[PyObject](),
            lstat: ptr[PyObject] = ptr[PyObject](),
            d_ino: u64 = 0,
            dir_fd: i32 = 0,
            d_type: u8 = 0;
    }
}

glob DirEntry_token = ClassToken(),
     ScandirIterator_token = ClassToken(),
     DIR_ENTRY_RECORD_SIZE: int = 48,
     DIR_ENTRY_MEMBERS: list[MemberField] = [
         MemberField(
             name="name",
             kind=MemberType.OBJECT_EX.value,
             offset=0,
             readonly=True,
             doc="the entry's base filename, relative to scandir() \"path\" argument"
         ),
         MemberField(
             name="path",
             kind=MemberType.OBJECT_EX.value,
             offset=8,
             readonly=True,
             doc="the entry's full path name; equivalent to\nos.path.join(scandir_path, entry.name)"
         )
     ];

def:priv dir_entry(instance: ptr[PyObject]) -> ptr[DirEntryRecord] {
    return ptr[DirEntryRecord](jacpy_binding_record(instance, DirEntry_token.handle));
}

def DirEntry_dealloc(instance: ptr[PyObject]) {
    fields = dir_entry(instance);
    for held in [
        fields.view(1)[0].name,
        fields.view(1)[0].path,
        fields.view(1)[0].stat,
        fields.view(1)[0].lstat
    ] {
        jacpy_release(held);
    }
    dispose_payload(instance, DirEntry_token.handle);
}

def DirEntry_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat("<DirEntry %R>", dir_entry(instance).view(1)[0].name);
}

def os_DirEntry_is_symlink_impl(
    instance: ptr[PyObject], defining_class: ptr[PyObject]
) -> i32 {
    d_type = i64(dir_entry(instance).view(1)[0].d_type);
    if d_type != DT_UNKNOWN {
        return i32(1) if d_type == DT_LNK else i32(0);
    }
    return DirEntry_test_mode(defining_class, instance, False, S_IFLNK);
}

def os_DirEntry_is_junction_impl(instance: ptr[PyObject]) -> i32 {
    return i32(0);
}

def:priv DirEntry_fetch_stat(
    module: ptr[PyObject], instance: ptr[PyObject], follow_symlinks: bool
) -> ptr[PyObject] {
    fields = dir_entry(instance);
    encoded = NULL;
    if PyUnicode_FSConverter(fields.view(1)[0].path, &mut encoded) == 0 {
        return NULL;
    }
    path = PyBytes_AsString(encoded);
    st = _Py_stat_struct();
    result = i32(0);
    if fields.view(1)[0].dir_fd != DEFAULT_DIR_FD {
        if not HAVE_FSTATAT {
            jacpy_release(encoded);
            PyErr_Format(PyExc_NotImplementedError, "can't fetch stat");
            return NULL;
        }
        dir_fd = fields.view(1)[0].dir_fd;
        thread = PyEval_SaveThread();
        result = jacpy_fstatat(
            dir_fd,
            path,
            &mut st,
            i32(0) if follow_symlinks else i32(AT_SYMLINK_NOFOLLOW)
        );
        PyEval_RestoreThread(thread);
    } else {
        thread = PyEval_SaveThread();
        result = jacpy_stat(path, &mut st)
            if follow_symlinks
            else jacpy_lstat(path, &mut st);
        PyEval_RestoreThread(thread);
    }
    saved_errno = jacpy_errno();
    jacpy_release(encoded);
    if result != 0 {
        jacpy_set_errno(saved_errno);
        path_object_error(fields.view(1)[0].path);
        return NULL;
    }
    return _pystat_fromstructstat(module, st);
}

def:priv DirEntry_get_lstat(
    defining_class: ptr[PyObject], instance: ptr[PyObject]
) -> ptr[PyObject] {
    fields = dir_entry(instance);
    if not fields.view(1)[0].lstat {
        module = PyType_GetModule(defining_class);
        fetched = DirEntry_fetch_stat(module, instance, False);
        dir_entry(instance).view(1)[0].lstat = fetched;
    }
    return Py_XNewRef(dir_entry(instance).view(1)[0].lstat);
}

def os_DirEntry_stat_impl(
    instance: ptr[PyObject], defining_class: ptr[PyObject], follow_symlinks: bool
) -> ptr[PyObject] {
    if not follow_symlinks {
        return DirEntry_get_lstat(defining_class, instance);
    }
    if not dir_entry(instance).view(1)[0].stat {
        result = os_DirEntry_is_symlink_impl(instance, defining_class);
        if result == -1 {
            return NULL;
        }
        fetched = NULL;
        if result != 0 {
            module = PyType_GetModule(defining_class);
            fetched = DirEntry_fetch_stat(module, instance, True);
        } else {
            fetched = DirEntry_get_lstat(defining_class, instance);
        }
        dir_entry(instance).view(1)[0].stat = fetched;
    }
    return Py_XNewRef(dir_entry(instance).view(1)[0].stat);
}

# DirEntry_test_mode(): -1 with the exception set, 0 for False, 1 for True.
def:priv DirEntry_test_mode(
    defining_class: ptr[PyObject],
    instance: ptr[PyObject],
    follow_symlinks: bool,
    mode_bits: u64
) -> i32 {
    d_type = i64(dir_entry(instance).view(1)[0].d_type);
    is_symlink = d_type == DT_LNK;
    need_stat = d_type == DT_UNKNOWN or (follow_symlinks and is_symlink);
    if need_stat {
        stat = os_DirEntry_stat_impl(instance, defining_class, follow_symlinks);
        if not stat {
            if PyErr_ExceptionMatches(PyExc_FileNotFoundError) != 0 {
                # A file that no longer exists is not a file or directory.
                PyErr_Clear();
                return i32(0);
            }
            return i32(-1);
        }
        module = PyType_GetModule(defining_class);
        st_mode = PyObject_GetAttr(stat, state_object(module, STATE_ST_MODE));
        jacpy_release(stat);
        if not st_mode {
            return i32(-1);
        }
        mode = PyLong_AsLong(st_mode);
        jacpy_release(st_mode);
        if mode == -1 and PyErr_Occurred() {
            return i32(-1);
        }
        return i32(1) if (u64.wrap(mode) & S_IFMT) == mode_bits else i32(0);
    }
    if is_symlink {
        return i32(0);
    }
    if mode_bits == S_IFDIR {
        return i32(1) if d_type == DT_DIR else i32(0);
    }
    return i32(1) if d_type == DT_REG else i32(0);
}

def os_DirEntry_is_dir_impl(
    instance: ptr[PyObject], defining_class: ptr[PyObject], follow_symlinks: bool
) -> i32 {
    return DirEntry_test_mode(defining_class, instance, follow_symlinks, S_IFDIR);
}

def os_DirEntry_is_file_impl(
    instance: ptr[PyObject], defining_class: ptr[PyObject], follow_symlinks: bool
) -> i32 {
    return DirEntry_test_mode(defining_class, instance, follow_symlinks, S_IFREG);
}

def os_DirEntry_inode_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromUnsignedLongLong(dir_entry(instance).view(1)[0].d_ino);
}

def os_DirEntry___fspath___impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(dir_entry(instance).view(1)[0].path);
}

# join_path_filename(): "<path>/<name>" in PyMem memory ("." for no path).
def:priv join_path_filename(
    path_narrow: ptr[u8], name: ptr[u8], length: i64
) -> ptr[u8] {
    base = path_narrow or ptr[u8](".");
    base_length = i64(strlen(base));
    joined = ptr[u8](PyMem_Malloc(u64(base_length + 1 + length + 1)));
    if not joined {
        PyErr_NoMemory();
        return joined;
    }
    for index in range(int(base_length)) {
        (joined + index).view(1)[0] = (base + index).view(1)[0];
    }
    position = base_length;
    if position > 0 and (joined + (position - 1)).view(1)[0] != u8(47) {
        (joined + position).view(1)[0] = u8(47);
        position += 1;
    }
    for index in range(int(length)) {
        (joined + (position + index)).view(1)[0] = (name + index).view(1)[0];
    }
    (joined + (position + length)).view(1)[0] = u8(0);
    return joined;
}

# DirEntry_from_posix_info()
def:priv DirEntry_from_posix_info(
    module: ptr[PyObject],
    path: path_t,
    name: ptr[u8],
    name_length: i64,
    d_ino: u64,
    d_type: i64
) -> ptr[PyObject] {
    dir_item = jacpy_binding_allocate(state_object(module, STATE_DIR_ENTRY_TYPE));
    if not dir_item {
        return NULL;
    }
    fields = dir_entry(dir_item);
    joined = ptr[u8]();
    if path.fd != -1 {
        fields.view(1)[0].dir_fd = path.fd;
    } else {
        fields.view(1)[0].dir_fd = DEFAULT_DIR_FD;
        joined = join_path_filename(path.narrow, name, name_length);
        if not joined {
            jacpy_release(dir_item);
            return NULL;
        }
    }
    entry_name = NULL;
    entry_path = NULL;
    if not path.narrow or jacpy_is_bytes(path.object) == 0 {
        entry_name = PyUnicode_DecodeFSDefaultAndSize(name, name_length);
        if joined {
            entry_path = PyUnicode_DecodeFSDefault(joined);
        }
    } else {
        entry_name = PyBytes_FromStringAndSize(name, name_length);
        if joined {
            entry_path = PyBytes_FromString(joined);
        }
    }
    PyMem_Free(joined);
    fields.view(1)[0].name = entry_name;
    if not entry_name {
        jacpy_release(entry_path);
        jacpy_release(dir_item);
        return NULL;
    }
    if path.fd != -1 {
        entry_path = Py_NewRef(entry_name);
    } elif not entry_path {
        jacpy_release(dir_item);
        return NULL;
    }
    fields.view(1)[0].path = entry_path;
    fields.view(1)[0].d_type = u8(d_type);
    fields.view(1)[0].d_ino = d_ino;
    return dir_item;
}

# --- scandir ---------------------------------------------------------------

"""ScandirIterator's state: the path it owns and the open DIR *."""
obj ScandirState(NativeState) {
    has path: path_t,
        directory: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
}

def:priv scandir_state(instance: ptr[PyObject]) -> (ScandirState | None) {
    if jacpy_binding_native_present(instance, ScandirIterator_token.handle) == 0 {
        return None;
    }
    state = jacpy_binding_native_get(instance, ScandirIterator_token.handle);
    if isinstance(state, ScandirState) {
        return state;
    }
    return None;
}

# ScandirIterator_closedir()
def:priv scandir_closedir(state: ScandirState) {
    directory = state.directory;
    if not directory {
        return;
    }
    state.directory = ptr();
    close_directory(directory, bool(HAVE_FDOPENDIR) and state.path.fd != -1);
}

def ScandirIterator_iternext(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = scandir_state(instance);
    # Iterated twice, or closed explicitly.
    if state is None or not state.directory {
        return NULL;
    }
    while True {
        kind = i64(0);
        inode = u64(0);
        jacpy_set_errno(0);
        thread = PyEval_SaveThread();
        name = jacpy_readdir_entry(state.directory, &mut kind, &mut inode);
        PyEval_RestoreThread(thread);
        if not name {
            if jacpy_errno() != 0 {
                path_error(state.path);
            }
            break;
        }
        length = i64(strlen(name));
        if not is_dot(name, length) {
            module = PyType_GetModule(Py_TYPE(instance));
            dir_item = DirEntry_from_posix_info(
                module, state.path, name, length, inode, kind
            );
            if not dir_item {
                break;
            }
            return dir_item;
        }
    }
    scandir_closedir(state);
    return NULL;
}

def ScandirIterator_close(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = scandir_state(instance);
    if state is not None {
        scandir_closedir(state);
    }
    return Py_NewRef(Py_None);
}

def ScandirIterator_enter(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_NewRef(instance);
}

def ScandirIterator_exit(
    instance: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    return ScandirIterator_close(instance, NULL);
}

def ScandirIterator_finalize(instance: ptr[PyObject]) {
    # Keep the current exception, if any.
    exc = PyErr_GetRaisedException();
    state = scandir_state(instance);
    if state is not None {
        if state.directory {
            scandir_closedir(state);
            if PyErr_ResourceWarning(
                instance, 1, "unclosed scandir iterator %R", instance
            )
                != 0 {
                # Spurious errors can appear at shutdown.
                if PyErr_ExceptionMatches(PyExc_Warning) != 0 {
                    PyErr_FormatUnraisable(
                        "Exception ignored while finalizing scandir iterator %R",
                        instance
                    );
                }
            }
        }
        state.path.clear();
    }
    PyErr_SetRaisedException(exc);
}

def ScandirIterator_dealloc(instance: ptr[PyObject]) {
    if PyObject_CallFinalizerFromDealloc(instance) < 0 {
        return;
    }
    dispose_payload(instance, ScandirIterator_token.handle);
}

def os_scandir_impl(module: ptr[PyObject], path: path_t) -> ptr[PyObject] {
    if not audit_event("os.scandir", [Py_NewRef(path.object or Py_None)]) {
        return NULL;
    }
    iterator = jacpy_binding_allocate(
        state_object(module, STATE_SCANDIR_ITERATOR_TYPE)
    );
    if not iterator {
        return NULL;
    }
    # Move the ownership of the path to the iterator.
    owned = path_t(
        function_name=path.function_name,
        argument_name=path.argument_name,
        nullable=path.nullable,
        nonstrict=path.nonstrict,
        make_wide=path.make_wide,
        suppress_value_error=path.suppress_value_error,
        allow_fd=path.allow_fd,
        wide=path.wide,
        narrow=path.narrow,
        fd=path.fd,
        is_fd=path.is_fd,
        value_error=path.value_error,
        length=path.length,
        object=path.object,
        cleanup=path.cleanup
    );
    path.wide = ptr();
    path.narrow = ptr[u8]();
    path.object = NULL;
    path.cleanup = NULL;
    state = ScandirState(path=owned);
    jacpy_binding_native_set(iterator, ScandirIterator_token.handle, state);
    jacpy_set_errno(0);
    fd = i32(-1);
    directory = ptr();
    if bool(HAVE_FDOPENDIR) and owned.fd != -1 {
        # closedir() closes the FD, so it is duplicated.
        fd = _Py_dup(owned.fd);
        if fd == -1 {
            jacpy_release(iterator);
            return NULL;
        }
        thread = PyEval_SaveThread();
        directory = jacpy_fdopendir(fd);
        PyEval_RestoreThread(thread);
    } else {
        name = owned.narrow or ptr[u8](".");
        thread = PyEval_SaveThread();
        directory = jacpy_opendir(name);
        PyEval_RestoreThread(thread);
    }
    if not directory {
        path_error(owned);
        if fd != -1 {
            thread = PyEval_SaveThread();
            close(fd);
            PyEval_RestoreThread(thread);
        }
        jacpy_release(iterator);
        return NULL;
    }
    state.directory = directory;
    return iterator;
}

# --- module exec -----------------------------------------------------------

# stat_result and statvfs_result, with stat_result's tp_new wrapped by
# statresult_new, as posixmodule_exec() makes them.
def posix_stat_exec(module: ptr[PyObject]) -> bool {
    stat_type = struct_sequence_type(
        "os.stat_result", STAT_RESULT_DOC, STAT_RESULT_FIELDS + STAT_EXTRA_FIELDS, 10
    );
    if not add_state_owned(module, STATE_STAT_RESULT_TYPE, "stat_result", stat_type) {
        return False;
    }
    layout = ptr[TypeLayout](stat_type);
    posix_state(module).statresult_new_orig = int(layout.view(1)[0].tp_new);
    layout.view(1)[0].tp_new = statresult_new;
    statvfs_type = struct_sequence_type(
        "os.statvfs_result", STATVFS_RESULT_DOC, STATVFS_RESULT_FIELDS, 10
    );
    return add_state_owned(
        module, STATE_STATVFS_RESULT_TYPE, "statvfs_result", statvfs_type
    );
}
