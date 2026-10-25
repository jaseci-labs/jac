import from c {
    def PyUnicode_FSConverter(arg0: ptr[PyObject], arg1: &mut ptr[PyObject]) -> i32;  def open(
        path: ptr[u8], flags: i32, *args: any
    ) -> i32;  def close(fd: i32) -> i32;  def lseek(
        fd: i32, offset: i64, whence: i32
    ) -> i64;  def isatty(fd: i32) -> i32;  def ftruncate(
        fd: i32, length: i64
    ) -> i32;  def jacpy_stack_address(slots: &mut IOStack) -> int;  glob _Py_open_cloexec_works:
             i32; obj fileio {
        has ob_base: _object,
            fd: i32,
            created: u8,
            readable: u8,
            writable: u8,
            appending: u8,
            seekable: i8,
            closefd: u8,
            finalizing: u8,
            stat_atopen: ptr[_Py_stat_struct],
            weakreflist: ptr[PyObject],
            dict: ptr[PyObject];
    }  obj FileIOFastCall {
        has call:
            Callable[
                [ptr[PyObject], ptr[ptr[PyObject]], i64, ptr[PyObject]],
                ptr[PyObject]
            ] = 0;
    }  glob:priv fileio_read_glue: FileIOFastCall = FileIOFastCall(),
         fileio_readinto_glue: FileIOFastCall = FileIOFastCall(),
         fileio_write_glue: FileIOFastCall = FileIOFastCall();
}

glob FILEIO_SIZE: Final[i64] = 56,
     FILEIO_FINALIZING: Final[i64] = 26,
     FILEIO_WEAKREFLIST: Final[i64] = 40,
     FILEIO_DICT: Final[i64] = 48,
     LARGE_BUFFER_CUTOFF_SIZE: Final[i64] = 65536;

def:priv fileio_record(op: ptr[PyObject]) -> ptr[fileio];

import from c {
    def _PyFileIO_closed(self_: ptr[PyObject]) -> i32 {
        if fileio_record(self_).view(1)[0].fd < 0 {
            return 1;
        }
        return 0;
    }
}

def fileio_dealloc_warn(op: ptr[PyObject], source: ptr[PyObject]) -> ptr[PyObject];

def internal_close(op: ptr[PyObject]) -> i32;

def _io_FileIO_close_impl(op: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject];

def fileio_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def:priv fileio_init_bad_mode -> i32;

def:priv fileio_init_failed(
    op: ptr[PyObject], fd_is_own: bool, stringobj: ptr[PyObject], modeobj: ptr[PyObject]
) -> i32;

def _io_FileIO___init___impl(
    op: ptr[PyObject],
    nameobj: ptr[PyObject],
    mode: str,
    closefd: bool,
    opener: ptr[PyObject]
) -> i32;

def fileio_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def fileio_clear(op: ptr[PyObject]) -> i32;

def fileio_dealloc(op: ptr[PyObject]);

def:priv err_closed -> ptr[PyObject];

def:priv err_mode(state: ptr[IOModuleState], writing: bool) -> ptr[PyObject];

def _io_FileIO_fileno_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_FileIO_readable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_FileIO_writable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_FileIO_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def:priv fileio_readinto_body(
    op: ptr[PyObject], buf: ptr, length: i64
) -> ptr[PyObject];

def _io_FileIO_readinto_impl(
    op: ptr[PyObject], cls: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def:priv new_buffersize(currentsize: i64) -> i64;

def _io_FileIO_readall_impl(op: ptr[PyObject]) -> ptr[PyObject];

def:priv fileio_read_body(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def _io_FileIO_read_impl(
    op: ptr[PyObject], cls: ptr[PyObject], size: i64
) -> ptr[PyObject];

def:priv fileio_write_body(op: ptr[PyObject], buf: ptr, length: i64) -> ptr[PyObject];

def _io_FileIO_write_impl(
    op: ptr[PyObject], cls: ptr[PyObject], b: BufferArgument
) -> ptr[PyObject];

def portable_lseek(
    op: ptr[PyObject], posobj: ptr[PyObject], whence: i32, suppress_pipe_error: bool
) -> ptr[PyObject];

def _io_FileIO_seek_impl(
    op: ptr[PyObject], pos: ptr[PyObject], whence: i32
) -> ptr[PyObject];

def _io_FileIO_tell_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_FileIO_truncate_impl(
    op: ptr[PyObject], cls: ptr[PyObject], posobj: ptr[PyObject]
) -> ptr[PyObject];

def:priv mode_string(op: ptr[PyObject]) -> ptr[u8];

def fileio_repr(op: ptr[PyObject]) -> ptr[PyObject];

def _io_FileIO_isatty_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_FileIO_isatty_open_only(
    op: ptr[PyObject], dummy: ptr[PyObject]
) -> ptr[PyObject];

def fileio_get_closed(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def fileio_get_closefd(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def fileio_get_mode(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def fileio_get_blksize(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def:priv fileio_glue(
    glue: ptr[FileIOFastCall],
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def fileio_read_fast(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def fileio_readinto_fast(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def fileio_write_fast(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    glob:priv fileio_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("closed"),
                 get=fileio_get_closed,
                 doc=ptr[u8]("True if the file is closed")
             ),
             PyGetSetDef(
                 name=ptr[u8]("closefd"),
                 get=fileio_get_closefd,
                 doc=ptr[u8]("True if the file descriptor will be closed by close().")
             ),
             PyGetSetDef(
                 name=ptr[u8]("mode"),
                 get=fileio_get_mode,
                 doc=ptr[u8]("String giving the file mode")
             ),
             PyGetSetDef(
                 name=ptr[u8]("_blksize"),
                 get=fileio_get_blksize,
                 doc=ptr[u8]("Stat st_blksize if available")
             ),
             PyGetSetDef()
         ],
         fileio_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("_finalizing"),
                 type_=Py_T_BOOL,
                 offset=FILEIO_FINALIZING,
                 flags=0
             ),
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=FILEIO_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=FILEIO_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         fileio_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(fileio_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(fileio_repr)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(fileio_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(fileio_clear)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(fileio_members))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(fileio_getsetlist))),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_io_FileIO___init___init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(fileio_new)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob fileio_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io.FileIO"),
             basicsize=i32(FILEIO_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(fileio_slots)
         );
}

def install_fileio_tables -> bool;

impl fileio_record(op: ptr[PyObject]) -> ptr[fileio] {
    return ptr[fileio](op);
}

impl fileio_dealloc_warn(op: ptr[PyObject], source: ptr[PyObject]) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd >= 0 and self_[0].closefd != 0 {
        exc = PyErr_GetRaisedException();
        if PyErr_ResourceWarning(source, 1, ptr[u8]("unclosed file %R"), source) != 0 {
            if PyErr_ExceptionMatches(PyExc_Warning) != 0 {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored while finalizing file %R"), op
                );
            }
        }
        PyErr_SetRaisedException(exc);
    }
    return object_new_ref(Py_None);
}

impl internal_close(op: ptr[PyObject]) -> i32 {
    self_ = fileio_record(op).view(1);
    err: i32 = 0;
    save_errno: i64 = 0;
    if self_[0].fd >= 0 {
        fd = self_[0].fd;
        self_[0].fd = -1;

        thread = PyEval_SaveThread();
        err = close(fd);
        if err < 0 {
            save_errno = jacpy_errno();
        }
        PyEval_RestoreThread(thread);
    }
    PyMem_Free(ptr(self_[0].stat_atopen));
    self_[0].stat_atopen = ptr[_Py_stat_struct]();
    if err < 0 {
        jacpy_set_errno(save_errno);
        PyErr_SetFromErrno(PyExc_OSError);
        return -1;
    }
    return 0;
}

impl _io_FileIO_close_impl(op: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    state = get_io_state_by_cls(cls);
    res = io_call_onearg(
        ptr[PyObject](state.view(1)[0].PyRawIOBase_Type), py_id(_Py_ID_close), op
    );
    if self_[0].closefd == 0 {
        self_[0].fd = -1;
        return res;
    }

    exc: ptr[PyObject] = NULL;
    if not res {
        exc = PyErr_GetRaisedException();
    }
    if self_[0].finalizing != 0 {
        r = fileio_dealloc_warn(op, op);
        if r {
            object_decref(r);
        } else {
            PyErr_Clear();
        }
    }
    rc = internal_close(op);
    if not res {
        _PyErr_ChainExceptions1(exc);
    }
    if rc < 0 {
        object_xdecref(res);
        res = NULL;
    }
    return res;
}

impl fileio_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        return NULL;
    }
    self_ = fileio_record(op).view(1);
    self_[0].fd = -1;
    self_[0].created = 0;
    self_[0].readable = 0;
    self_[0].writable = 0;
    self_[0].appending = 0;
    self_[0].seekable = -1;
    self_[0].stat_atopen = ptr[_Py_stat_struct]();
    self_[0].closefd = 1;
    self_[0].weakreflist = NULL;
    return op;
}

impl fileio_init_bad_mode -> i32 {
    PyErr_SetString(
        PyExc_ValueError,
        ptr[u8](
            "Must have exactly one of create/read/write/append mode and at most one plus"
        )
    );
    return -1;
}

impl fileio_init_failed(
    op: ptr[PyObject], fd_is_own: bool, stringobj: ptr[PyObject], modeobj: ptr[PyObject]
) -> i32 {
    self_ = fileio_record(op).view(1);
    if not fd_is_own {
        self_[0].fd = -1;
    }
    if self_[0].fd >= 0 {
        exc = PyErr_GetRaisedException();
        internal_close(op);
        _PyErr_ChainExceptions1(exc);
    }
    PyMem_Free(ptr(self_[0].stat_atopen));
    self_[0].stat_atopen = ptr[_Py_stat_struct]();
    object_xdecref(stringobj);
    object_xdecref(modeobj);
    return -1;
}

impl _io_FileIO___init___impl(
    op: ptr[PyObject],
    nameobj: ptr[PyObject],
    mode: str,
    closefd: bool,
    opener: ptr[PyObject]
) -> i32 {
    self_ = fileio_record(op).view(1);
    name = ptr[u8]();
    stringobj: ptr[PyObject] = NULL;
    rwa = False;
    plus = False;
    flags: i32 = 0;
    fd: i32 = -1;
    fd_is_own = False;
    use_atomic_flag = True;
    async_err: i32 = 0;

    if self_[0].fd >= 0 {
        if self_[0].closefd != 0 {
            if internal_close(op) < 0 {
                return -1;
            }
        } else {
            self_[0].fd = -1;
        }
    }

    if jacpy_is_bool(nameobj) != 0 {
        if PyErr_WarnEx(
            PyExc_RuntimeWarning, ptr[u8]("bool is used as a file descriptor"), 1
        )
            != 0 {
            return -1;
        }
    }

    fd = PyLong_AsInt(nameobj);
    if fd < 0 {
        if not PyErr_Occurred() {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("negative file descriptor"));
            return -1;
        }
        PyErr_Clear();
    }

    if fd < 0 {
        if PyUnicode_FSConverter(nameobj, &mut stringobj) == 0 {
            return -1;
        }
        name = bytes_data(stringobj);
    }

    modeobj = jacpy_unicode_from_text(mode);
    if not modeobj {
        object_xdecref(stringobj);
        return -1;
    }
    cmode = PyUnicode_AsUTF8(modeobj);
    if not cmode {
        return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
    }
    s: i64 = 0;
    while cmode.view(s + 1)[s] != u8(0) {
        c = cmode.view(s + 1)[s];
        s += 1;
        if c == u8(120) {
            if rwa {
                fileio_init_bad_mode();
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
            rwa = True;
            self_[0].created = 1;
            self_[0].writable = 1;
            flags |= O_EXCL | O_CREAT;
        } elif c == u8(114) {
            if rwa {
                fileio_init_bad_mode();
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
            rwa = True;
            self_[0].readable = 1;
        } elif c == u8(119) {
            if rwa {
                fileio_init_bad_mode();
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
            rwa = True;
            self_[0].writable = 1;
            flags |= O_CREAT | O_TRUNC;
        } elif c == u8(97) {
            if rwa {
                fileio_init_bad_mode();
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
            rwa = True;
            self_[0].writable = 1;
            self_[0].appending = 1;
            flags |= O_APPEND | O_CREAT;
        } elif c == u8(43) {
            if plus {
                fileio_init_bad_mode();
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
            self_[0].readable = 1;
            self_[0].writable = 1;
            plus = True;
        } elif c != u8(98) {
            PyErr_Format(PyExc_ValueError, ptr[u8]("invalid mode: %.200s"), cmode);
            return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
        }
    }

    if not rwa {
        fileio_init_bad_mode();
        return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
    }

    if self_[0].readable != 0 and self_[0].writable != 0 {
        flags |= O_RDWR;
    } elif self_[0].readable != 0 {
        flags |= O_RDONLY;
    } else {
        flags |= O_WRONLY;
    }

    flags |= O_CLOEXEC;

    if PySys_Audit("open", "Osi", nameobj, cmode, flags) < 0 {
        return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
    }

    if fd >= 0 {
        self_[0].fd = fd;
        self_[0].closefd = u8(1) if closefd else u8(0);
    } else {
        self_[0].closefd = 1;
        if not closefd {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("Cannot use closefd=False with file name")
            );
            return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
        }
        jacpy_set_errno(0);
        if opener == Py_None {
            while True {
                thread = PyEval_SaveThread();
                self_[0].fd = open(name, flags, i32(0o666));
                PyEval_RestoreThread(thread);
                if not (self_[0].fd < 0 and jacpy_errno() == i64(EINTR)) {
                    break;
                }
                async_err = PyErr_CheckSignals();
                if async_err != 0 {
                    break;
                }
            }

            if async_err != 0 {
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }

            if self_[0].fd < 0 {
                PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, nameobj);
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
        } else {
            use_atomic_flag = False;
            flagsobj = PyLong_FromLong(i64(flags));
            if not flagsobj {
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
            fdobj = io_call_function(opener, nameobj, flagsobj, NULL, NULL, 2);
            object_decref(flagsobj);
            if not fdobj {
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
            if not long_check(fdobj) {
                object_decref(fdobj);
                PyErr_SetString(
                    PyExc_TypeError, ptr[u8]("expected integer from opener")
                );
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
            self_[0].fd = PyLong_AsInt(fdobj);
            object_decref(fdobj);
            if self_[0].fd < 0 {
                if not PyErr_Occurred() {
                    PyErr_Format(
                        PyExc_ValueError, ptr[u8]("opener returned %d"), self_[0].fd
                    );
                }
                return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
            }
        }
        fd_is_own = True;
        inherit_status: i32 = 0;
        if use_atomic_flag {
            inherit_status = _Py_set_inheritable(
                self_[0].fd, 0, &mut _Py_open_cloexec_works
            );
        } else {
            inherit_status = _Py_set_inheritable(self_[0].fd, 0, None);
        }
        if inherit_status < 0 {
            return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
        }
    }

    PyMem_Free(ptr(self_[0].stat_atopen));
    self_[0].stat_atopen = ptr[_Py_stat_struct](PyMem_Malloc(IO_STAT_SIZE));
    if not self_[0].stat_atopen {
        PyErr_NoMemory();
        return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
    }
    status = _Py_stat_struct();
    thread = PyEval_SaveThread();
    fstat_result = _Py_fstat_noraise(self_[0].fd, &mut status);
    PyEval_RestoreThread(thread);
    if fstat_result < 0 {
        if jacpy_errno() == i64(EBADF) {
            PyErr_SetFromErrno(PyExc_OSError);
            return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
        }

        PyMem_Free(ptr(self_[0].stat_atopen));
        self_[0].stat_atopen = ptr[_Py_stat_struct]();
    } else {
        self_[0].stat_atopen.view(1)[0] = status;
        if (u64(stat_mode(status)) & u64(S_IFMT)) == u64(S_IFDIR) {
            jacpy_set_errno(i64(EISDIR));
            PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, nameobj);
            return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
        }
    }

    if PyObject_SetAttr(op, py_id(_Py_ID_name), nameobj) < 0 {
        return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
    }

    if self_[0].appending != 0 {
        pos = portable_lseek(op, NULL, 2, True);
        if not pos {
            return fileio_init_failed(op, fd_is_own, stringobj, modeobj);
        }
        object_decref(pos);
    }

    object_xdecref(stringobj);
    object_decref(modeobj);
    return 0;
}

impl fileio_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(fileio_record(op).view(1)[0].dict, visitor, arg);
}

impl fileio_clear(op: ptr[PyObject]) -> i32 {
    py_clear(ptr[ptr[PyObject]](ptr[u8](op) + FILEIO_DICT));
    return 0;
}

impl fileio_dealloc(op: ptr[PyObject]) {
    self_ = fileio_record(op).view(1);
    self_[0].finalizing = 1;
    if _PyIOBase_finalize(op) < 0 {
        return;
    }

    object_gc_untrack(op);
    if self_[0].stat_atopen {
        PyMem_Free(ptr(self_[0].stat_atopen));
        self_[0].stat_atopen = ptr[_Py_stat_struct]();
    }
    if self_[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    fileio_clear(op);

    tp = object_type(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl err_closed -> ptr[PyObject] {
    PyErr_SetString(PyExc_ValueError, ptr[u8]("I/O operation on closed file"));
    return NULL;
}

impl err_mode(state: ptr[IOModuleState], writing: bool) -> ptr[PyObject] {
    if writing {
        return PyErr_Format(
            state.view(1)[0].unsupported_operation,
            ptr[u8]("File not open for %s"),
            ptr[u8]("writing")
        );
    }
    return PyErr_Format(
        state.view(1)[0].unsupported_operation,
        ptr[u8]("File not open for %s"),
        ptr[u8]("reading")
    );
}

impl _io_FileIO_fileno_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    fd = fileio_record(op).view(1)[0].fd;
    if fd < 0 {
        return err_closed();
    }
    return PyLong_FromLong(i64(fd));
}

impl _io_FileIO_readable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd < 0 {
        return err_closed();
    }
    return PyBool_FromLong(i64(self_[0].readable));
}

impl _io_FileIO_writable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd < 0 {
        return err_closed();
    }
    return PyBool_FromLong(i64(self_[0].writable));
}

impl _io_FileIO_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd < 0 {
        return err_closed();
    }
    if self_[0].seekable < 0 {
        pos = portable_lseek(op, NULL, SEEK_CUR, False);
        if not pos {
            PyErr_Clear();
        } else {
            object_decref(pos);
        }
    }
    return PyBool_FromLong(i64(self_[0].seekable));
}

impl fileio_readinto_body(op: ptr[PyObject], buf: ptr, length: i64) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd < 0 {
        return err_closed();
    }
    if self_[0].readable == 0 {
        return err_mode(find_io_state_by_def(object_type(op)), False);
    }

    n = _Py_read(self_[0].fd, buf, u64(length));

    err = jacpy_errno();

    if n == -1 {
        if err == i64(EAGAIN) {
            PyErr_Clear();
            return object_new_ref(Py_None);
        }
        return NULL;
    }

    return PyLong_FromSsize_t(n);
}

impl _io_FileIO_readinto_impl(
    op: ptr[PyObject], cls: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd < 0 {
        return err_closed();
    }
    if self_[0].readable == 0 {
        return err_mode(get_io_state_by_cls(cls), False);
    }
    return fileio_readinto_body(op, buffer.address(), buffer.size());
}

impl new_buffersize(currentsize: i64) -> i64 {
    addend: i64 = 0;

    if currentsize > LARGE_BUFFER_CUTOFF_SIZE {
        addend = currentsize >> 3;
    } else {
        addend = 256 + currentsize;
    }
    if addend < IO_SMALLCHUNK {
        addend = IO_SMALLCHUNK;
    }
    return addend + currentsize;
}

impl _io_FileIO_readall_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    end: i64 = -1;
    bytes_read: i64 = 0;
    bufsize: i64 = 0;

    if self_[0].fd < 0 {
        return err_closed();
    }

    if self_[0].stat_atopen and self_[0].stat_atopen.view(1)[0].st_size < IO_READ_MAX {
        end = self_[0].stat_atopen.view(1)[0].st_size;
    }

    if end <= 0 {
        bufsize = IO_SMALLCHUNK;
    } else {
        if end > IO_READ_MAX - 1 {
            bufsize = IO_READ_MAX;
        } else {
            bufsize = end + 1;
        }
        if bufsize > LARGE_BUFFER_CUTOFF_SIZE {
            thread = PyEval_SaveThread();
            pos = lseek(self_[0].fd, 0, SEEK_CUR);
            PyEval_RestoreThread(thread);
            if end >= pos and pos >= 0 and (end - pos) < (IO_READ_MAX - 1) {
                bufsize = (end - pos) + 1;
            }
        }
    }

    result = PyBytes_FromStringAndSize(ptr[u8](), bufsize);
    if not result {
        return NULL;
    }

    while True {
        if bytes_read >= bufsize {
            bufsize = new_buffersize(bytes_read);
            if bufsize <= 0 {
                PyErr_SetString(
                    PyExc_OverflowError,
                    ptr[u8](
                        "unbounded read returned more bytes than a Python bytes object can hold"
                    )
                );
                object_decref(result);
                return NULL;
            }

            if object_size(result) < bufsize {
                if _PyBytes_Resize(&mut result, bufsize) < 0 {
                    return NULL;
                }
            }
        }

        n = _Py_read(
            self_[0].fd, ptr(bytes_data(result) + bytes_read), u64(bufsize - bytes_read)
        );

        if n == 0 {
            break;
        }
        if n == -1 {
            if jacpy_errno() == i64(EAGAIN) {
                PyErr_Clear();
                if bytes_read > 0 {
                    break;
                }
                object_decref(result);
                return object_new_ref(Py_None);
            }
            object_decref(result);
            return NULL;
        }
        bytes_read += n;
    }

    if object_size(result) > bytes_read {
        if _PyBytes_Resize(&mut result, bytes_read) < 0 {
            return NULL;
        }
    }
    return result;
}

impl fileio_read_body(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd < 0 {
        return err_closed();
    }
    if self_[0].readable == 0 {
        return err_mode(find_io_state_by_def(object_type(op)), False);
    }

    if size < 0 {
        return _io_FileIO_readall_impl(op);
    }

    if size > IO_READ_MAX {
        size = IO_READ_MAX;
    }

    bytes = PyBytes_FromStringAndSize(ptr[u8](), size);
    if not bytes {
        return NULL;
    }
    n = _Py_read(self_[0].fd, ptr(bytes_data(bytes)), u64(size));

    if n == -1 {
        err = jacpy_errno();
        object_decref(bytes);
        if err == i64(EAGAIN) {
            PyErr_Clear();
            return object_new_ref(Py_None);
        }
        return NULL;
    }

    if n != size {
        if _PyBytes_Resize(&mut bytes, n) < 0 {
            return NULL;
        }
    }

    return bytes;
}

impl _io_FileIO_read_impl(
    op: ptr[PyObject], cls: ptr[PyObject], size: i64
) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd < 0 {
        return err_closed();
    }
    if self_[0].readable == 0 {
        return err_mode(get_io_state_by_cls(cls), False);
    }
    return fileio_read_body(op, size);
}

impl fileio_write_body(op: ptr[PyObject], buf: ptr, length: i64) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd < 0 {
        return err_closed();
    }
    if self_[0].writable == 0 {
        return err_mode(find_io_state_by_def(object_type(op)), True);
    }

    n = _Py_write(self_[0].fd, buf, u64(length));

    err = jacpy_errno();

    if n < 0 {
        if err == i64(EAGAIN) {
            PyErr_Clear();
            return object_new_ref(Py_None);
        }
        return NULL;
    }

    return PyLong_FromSsize_t(n);
}

impl _io_FileIO_write_impl(
    op: ptr[PyObject], cls: ptr[PyObject], b: BufferArgument
) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    if self_[0].fd < 0 {
        return err_closed();
    }
    if self_[0].writable == 0 {
        return err_mode(get_io_state_by_cls(cls), True);
    }
    return fileio_write_body(op, b.address(), b.size());
}

impl portable_lseek(
    op: ptr[PyObject], posobj: ptr[PyObject], whence: i32, suppress_pipe_error: bool
) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    pos: i64 = 0;
    fd = self_[0].fd;

    if whence == 0 {
        whence = SEEK_SET;
    } elif whence == 1 {
        whence = SEEK_CUR;
    } elif whence == 2 {
        whence = SEEK_END;
    }

    if posobj {
        pos = PyLong_AsLongLong(posobj);
        if PyErr_Occurred() {
            return NULL;
        }
    }

    thread = PyEval_SaveThread();
    res = lseek(fd, pos, whence);
    PyEval_RestoreThread(thread);

    if self_[0].seekable < 0 {
        self_[0].seekable = i8(1) if res >= 0 else i8(0);
    }

    if res < 0 {
        if suppress_pipe_error and jacpy_errno() == i64(ESPIPE) {
            res = 0;
        } else {
            return PyErr_SetFromErrno(PyExc_OSError);
        }
    }

    return PyLong_FromLongLong(res);
}

impl _io_FileIO_seek_impl(
    op: ptr[PyObject], pos: ptr[PyObject], whence: i32
) -> ptr[PyObject] {
    if fileio_record(op).view(1)[0].fd < 0 {
        return err_closed();
    }
    return portable_lseek(op, pos, whence, False);
}

impl _io_FileIO_tell_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if fileio_record(op).view(1)[0].fd < 0 {
        return err_closed();
    }
    return portable_lseek(op, NULL, 1, False);
}

impl _io_FileIO_truncate_impl(
    op: ptr[PyObject], cls: ptr[PyObject], posobj: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    fd = self_[0].fd;
    if fd < 0 {
        return err_closed();
    }
    if self_[0].writable == 0 {
        return err_mode(get_io_state_by_cls(cls), True);
    }

    if posobj == Py_None {
        posobj = portable_lseek(op, NULL, 1, False);
        if not posobj {
            return NULL;
        }
    } else {
        object_incref(posobj);
    }

    pos = PyLong_AsLongLong(posobj);
    if PyErr_Occurred() {
        object_decref(posobj);
        return NULL;
    }

    thread = PyEval_SaveThread();
    jacpy_set_errno(0);
    ret = ftruncate(fd, pos);
    PyEval_RestoreThread(thread);

    if ret != 0 {
        PyErr_SetFromErrno(PyExc_OSError);
        object_decref(posobj);
        return NULL;
    }

    if self_[0].stat_atopen {
        PyMem_Free(ptr(self_[0].stat_atopen));
        self_[0].stat_atopen = ptr[_Py_stat_struct]();
    }

    return posobj;
}

impl mode_string(op: ptr[PyObject]) -> ptr[u8] {
    self_ = fileio_record(op).view(1);
    if self_[0].created != 0 {
        if self_[0].readable != 0 {
            return ptr[u8]("xb+");
        }
        return ptr[u8]("xb");
    }
    if self_[0].appending != 0 {
        if self_[0].readable != 0 {
            return ptr[u8]("ab+");
        }
        return ptr[u8]("ab");
    } elif self_[0].readable != 0 {
        if self_[0].writable != 0 {
            return ptr[u8]("rb+");
        }
        return ptr[u8]("rb");
    }
    return ptr[u8]("wb");
}

impl fileio_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = fileio_record(op).view(1);
    type_name = object_type(op).view(1)[0].tp_name;

    if self_[0].fd < 0 {
        return PyUnicode_FromFormat("<%.100s [closed]>", type_name);
    }

    nameobj: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(op, py_id(_Py_ID_name), &mut nameobj) < 0 {
        return NULL;
    }
    closefd_text = ptr[u8]("True") if self_[0].closefd != 0 else ptr[u8]("False");
    res: ptr[PyObject] = NULL;
    if not nameobj {
        res = PyUnicode_FromFormat(
            "<%.100s fd=%d mode='%s' closefd=%s>",
            type_name,
            self_[0].fd,
            mode_string(op),
            closefd_text
        );
    } else {
        status = Py_ReprEnter(op);
        if status == 0 {
            res = PyUnicode_FromFormat(
                "<%.100s name=%R mode='%s' closefd=%s>",
                type_name,
                nameobj,
                mode_string(op),
                closefd_text
            );
            Py_ReprLeave(op);
        } elif status > 0 {
            PyErr_Format(
                PyExc_RuntimeError,
                ptr[u8]("reentrant call inside %.100s.__repr__"),
                type_name
            );
        }
        object_decref(nameobj);
    }
    return res;
}

impl _io_FileIO_isatty_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    fd = fileio_record(op).view(1)[0].fd;
    if fd < 0 {
        return err_closed();
    }
    thread = PyEval_SaveThread();
    res = isatty(fd);
    PyEval_RestoreThread(thread);
    return PyBool_FromLong(i64(res));
}

impl _io_FileIO_isatty_open_only(
    op: ptr[PyObject], dummy: ptr[PyObject]
) -> ptr[PyObject] {
    st = fileio_record(op).view(1)[0].stat_atopen;
    if st and (u64(stat_mode(st.view(1)[0])) & u64(S_IFMT)) != u64(S_IFCHR) {
        return object_new_ref(io_false());
    }
    return _io_FileIO_isatty_impl(op);
}

impl fileio_get_closed(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyBool_FromLong(i64(1) if fileio_record(op).view(1)[0].fd < 0 else i64(0));
}

impl fileio_get_closefd(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyBool_FromLong(i64(fileio_record(op).view(1)[0].closefd));
}

impl fileio_get_mode(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyUnicode_FromString(mode_string(op));
}

impl fileio_get_blksize(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    st = fileio_record(op).view(1)[0].stat_atopen;
    if st and stat_blksize(st.view(1)[0]) > 1 {
        return PyLong_FromLong(stat_blksize(st.view(1)[0]));
    }
    return PyLong_FromLong(DEFAULT_BUFFER_SIZE);
}

impl fileio_glue(
    glue: ptr[FileIOFastCall],
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return glue.view(1)[0].call(receiver, args, nargs, kwnames);
}

impl fileio_read_fast(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames {
        if nargs == 0 {
            return fileio_read_body(receiver, -1);
        }
        if nargs == 1 {
            arg = args.view(1)[0];
            if arg == Py_None {
                return fileio_read_body(receiver, -1);
            }
            if jacpy_is_exact_long(arg) != 0 {
                size = PyNumber_AsSsize_t(arg, PyExc_OverflowError);
                if size == -1 and PyErr_Occurred() {
                    return NULL;
                }
                return fileio_read_body(receiver, size);
            }
        }
    }
    return fileio_glue(addressof(fileio_read_glue), receiver, args, nargs, kwnames);
}

impl fileio_readinto_fast(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 1 and not kwnames {
        slots: own IOStack = IOStack();
        view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
        if PyObject_GetBuffer(args.view(1)[0], view, PyBUF_WRITABLE) == 0 {
            res = fileio_readinto_body(
                receiver, view.view(1)[0].buf, view.view(1)[0].length
            );
            PyBuffer_Release(view);
            return res;
        }
        PyErr_Clear();
    }
    return fileio_glue(addressof(fileio_readinto_glue), receiver, args, nargs, kwnames);
}

impl fileio_write_fast(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 1 and not kwnames {
        slots: own IOStack = IOStack();
        view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
        if PyObject_GetBuffer(args.view(1)[0], view, PyBUF_SIMPLE) == 0 {
            res = fileio_write_body(
                receiver, view.view(1)[0].buf, view.view(1)[0].length
            );
            PyBuffer_Release(view);
            return res;
        }
        PyErr_Clear();
    }
    return fileio_glue(addressof(fileio_write_glue), receiver, args, nargs, kwnames);
}

impl install_fileio_tables -> bool {
    methods: list[MethodDefinition] = [];
    for method in io_select_methods(
        FileIO_methods,
        [
            "read",
            "readall",
            "readinto",
            "write",
            "seek",
            "tell",
            "truncate",
            "close",
            "seekable",
            "readable",
            "writable",
            "fileno",
            "isatty"
        ]
    ) {
        callbacks = method.callbacks;
        if method.name == "read" {
            addressof(fileio_read_glue).view(1)[0].call = method.callbacks.fast_keywords;
            callbacks = MethodCallbacks(fast_keywords=fileio_read_fast);
        } elif method.name == "readinto" {
            addressof(fileio_readinto_glue).view(1)[0].call = method.callbacks.fast_keywords;
            callbacks = MethodCallbacks(fast_keywords=fileio_readinto_fast);
        } elif method.name == "write" {
            addressof(fileio_write_glue).view(1)[0].call = method.callbacks.fast_keywords;
            callbacks = MethodCallbacks(fast_keywords=fileio_write_fast);
        }
        methods.append(
            MethodDefinition(method.name, callbacks, method.doc, method.flags)
        );
    }
    methods.append(
        MethodDefinition(
            "_isatty_open_only",
            MethodCallbacks(positional=_io_FileIO_isatty_open_only),
            "",
            i64(METH_NOARGS)
        )
    );
    methods.append(
        MethodDefinition(
            "_dealloc_warn",
            MethodCallbacks(positional=fileio_dealloc_warn),
            "",
            i64(METH_O)
        )
    );
    methods.append(
        MethodDefinition(
            "__getstate__",
            MethodCallbacks(positional=_PyIOBase_cannot_pickle),
            "",
            i64(METH_NOARGS)
        )
    );
    FileIO_token.handle = ptr(addressof(fileio_spec));
    return io_fill_slots(
        ptr[PyType_Slot](addressof(fileio_slots)), methods, [], FileIO_doc
    );
}
