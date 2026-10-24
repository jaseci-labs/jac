import from c {
    def _PyRuntimeState_ReInitThreads(runtime: ptr[_PyRuntimeState]) -> PyStatus;  def _PyEval_ReInitThreads(
        tstate: ptr[PyThreadState]
    ) -> PyStatus;  def _PyInterpreterState_DeleteExceptMain(
        runtime: ptr[_PyRuntimeState]
    ) -> PyStatus;  def _PyPerfTrampoline_AfterFork_Child -> PyStatus;  def Py_ExitStatusException(
        status: PyStatus
    );  def _Py_FatalErrorFunc(function: str, message: str);
}
import from c {
    def wcslen(text: ptr) -> u64;  def strlen(text: ptr[u8]) -> u64;  def sigemptyset(
        mask: ptr
    ) -> i32;  def sigaddset(mask: ptr, signum: i32) -> i32;
}

glob DEFAULT_DIR_FD: i32 = i32(AT_FDCWD),
     PATH_HAVE_FCHDIR: int = HAVE_FCHDIR,
     PATH_HAVE_FCHMOD: int = HAVE_FCHMOD,
     PATH_HAVE_FCHOWN: int = HAVE_FCHOWN,
     PATH_HAVE_FDOPENDIR: int = HAVE_FDOPENDIR,
     PATH_HAVE_FEXECVE: int = HAVE_FEXECVE,
     PATH_HAVE_FPATHCONF: int = HAVE_FPATHCONF,
     PATH_HAVE_FSTATVFS: int = HAVE_FSTATVFS,
     PATH_HAVE_FTRUNCATE: int = HAVE_FTRUNCATE,
     PATH_UTIME_HAVE_FD: int = 1
         if HAVE_FUTIMENS or HAVE_FUTIMES or HAVE_FUTIMESAT
         else 0,
     CHMOD_DEFAULT_FOLLOW_SYMLINKS: bool = True,
     EFD_CLOEXEC: i32 = i32(EFD_CLOEXEC_VALUE),
     MFD_CLOEXEC: u32 = u32(MFD_CLOEXEC_VALUE),
     stdout: i32 = 1,
     INT_MAX: i64 = 2147483647,
     INT_MIN: i64 = -2147483648,
     STATE_BILLION: int = 0,
     STATE_DIR_ENTRY_TYPE: int = 1,
     STATE_SCANDIR_ITERATOR_TYPE: int = 2,
     STATE_SCHED_PARAM_TYPE: int = 3,
     STATE_STAT_RESULT_TYPE: int = 4,
     STATE_STATVFS_RESULT_TYPE: int = 5,
     STATE_TERMINAL_SIZE_TYPE: int = 6,
     STATE_TIMES_RESULT_TYPE: int = 7,
     STATE_UNAME_RESULT_TYPE: int = 8,
     STATE_WAITID_RESULT_TYPE: int = 9,
     STATE_STRUCT_RUSAGE: int = 10,
     STATE_ST_MODE: int = 11,
     STATE_COUNT: int = 12;

obj PosixState(NativeState) {
    has ticks_per_second: i64 = 0,
        statresult_new_orig: int = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
}

def state_object(module: ptr[PyObject], index: int) -> ptr[PyObject];

def posix_state(module: ptr[PyObject]) -> PosixState;

def interned(name: str) -> ptr[PyObject];

def posix_module -> ptr[PyObject];

def fileno(stream: i32) -> i32;

import from c {
    def _PyLong_FromUid(uid: u32) -> ptr[PyObject] {
        if uid == u32(0xFFFFFFFF) {
            return PyLong_FromLong(-1);
        }
        return PyLong_FromUnsignedLong(u64(uid));
    }  def _PyLong_FromGid(gid: u32) -> ptr[PyObject] {
        if gid == u32(0xFFFFFFFF) {
            return PyLong_FromLong(-1);
        }
        return PyLong_FromUnsignedLong(u64(gid));
    }  def _Py_Uid_Converter(value: ptr[PyObject], p: ptr[u32]) -> i32 {
        uid = id_converter(value, "uid");
        if uid is None {
            return i32(0);
        }
        p.view(1)[0] = uid;
        return i32(1);
    }  def _Py_Gid_Converter(value: ptr[PyObject], p: ptr[u32]) -> i32 {
        gid = id_converter(value, "gid");
        if gid is None {
            return i32(0);
        }
        p.view(1)[0] = gid;
        return i32(1);
    }
}

def:priv id_converter(value: ptr[PyObject], kind: str) -> (u32 | None);

def convert__Py_Uid_Converter(value: ptr[PyObject], fname: str, label: str) -> u32;

def convert__Py_Gid_Converter(value: ptr[PyObject], fname: str, label: str) -> u32;

def dev_value(device: u64) -> i64;

def _PyLong_FromDev(device: u64) -> ptr[PyObject];

def return_dev_t(device: u64) -> ptr[PyObject];

def dev_converter(value: ptr[PyObject]) -> (u64 | None);

def convert__Py_Dev_Converter(value: ptr[PyObject], fname: str, label: str) -> u64;

def fd_converter(value: ptr[PyObject]) -> (i32 | None);

def dir_fd_converter(value: ptr[PyObject]) -> (i32 | None);

def argument_unavailable_error(function_name: str, argument_name: str);

def dir_fd_unavailable(value: ptr[PyObject]) -> (i32 | None);

def:priv dir_fd_argument(value: ptr[PyObject], available: bool) -> i32;

def convert_dir_fd_converter(value: ptr[PyObject], fname: str, label: str) -> i32;

def convert_FACCESSAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_FCHMODAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_FCHOWNAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_FSTATAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_FUTIMENSAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_MKDIRAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_MKFIFOAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_MKNODAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_OPENAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_READLINKAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_SYMLINKAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def convert_UNLINKAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32;

def fd_specified(function_name: str, fd: i32) -> bool;

def follow_symlinks_specified(function_name: str, follow_symlinks: bool) -> bool;

def path_and_dir_fd_invalid(function_name: str, path: path_t, dir_fd: i32) -> bool;

def dir_fd_and_fd_invalid(function_name: str, dir_fd: i32, fd: i32) -> bool;

def fd_and_follow_symlinks_invalid(
    function_name: str, fd: i32, follow_symlinks: bool
) -> bool;

def dir_fd_and_follow_symlinks_invalid(
    function_name: str, dir_fd: i32, follow_symlinks: bool
) -> bool;

obj path_t {
    has function_name: str = "",
        argument_name: str = "",
        nullable: bool = False,
        nonstrict: bool = False,
        make_wide: bool = False,
        suppress_value_error: bool = False,
        allow_fd: bool = False,
        wide: ptr = ptr(),
        narrow: ptr[u8] = ptr[u8](),
        fd: i32 = -1,
        is_fd: bool = False,
        value_error: bool = False,
        length: i64 = 0,
        object: ptr[PyObject] = ptr[PyObject](),
        cleanup: ptr[PyObject] = ptr[PyObject]();

    def clear;
    def drop;
    def label -> str;
}

def PATH_T_INITIALIZE(
    function_name: str,
    argument_name: str,
    nullable: int,
    nonstrict: int,
    make_wide: int,
    suppress_value_error: int,
    allow_fd: int
) -> path_t;

def PATH_T_INITIALIZE_P(
    function_name: str,
    argument_name: str,
    nullable: int,
    nonstrict: int,
    suppress_value_error: int,
    allow_fd: int
) -> path_t;

def:priv path_format_error(path: path_t, template: str);

def:priv path_kind_text(path: path_t) -> str;

def path_converter(value: ptr[PyObject], path: path_t) -> bool;

def:priv path_success(path: path_t, current: ptr[PyObject], length: i64) -> bool;

def:priv path_type_error(path: path_t, current: ptr[PyObject]) -> bool;

def:priv path_failure(
    path: path_t, current: ptr[PyObject], encoded: ptr[PyObject], wide: ptr
) -> bool;

def convert_path_converter(value: ptr[PyObject], path: path_t) -> path_t;

def convert_idtype_t_converter(value: ptr[PyObject], fname: str, label: str) -> i32;

def convert_id_t(value: ptr[PyObject], fname: str, label: str) -> u32;

def convert_Py_off_t_converter(value: ptr[PyObject], fname: str, label: str) -> i64;

def PyLong_FromPy_off_t(offset: i64) -> ptr[PyObject];

def return_Py_off_t(offset: i64) -> ptr[PyObject];

def conv_confname(
    module: ptr[PyObject], value: ptr[PyObject], table_name: str
) -> (i32 | None);

def convert_conv_confname(
    module: ptr[PyObject], value: ptr[PyObject], fname: str, label: str, table_name: str
) -> i32;

import from c {
    def _Py_Sigset_Converter(value: ptr[PyObject], address: ptr) -> i32 {
        if sigemptyset(address) < 0 {
            PyErr_SetFromErrno(PyExc_OSError);
            return i32(0);
        }
        iterator = PyObject_GetIter(value);
        if not iterator {
            return i32(0);
        }
        while True {
            item = PyIter_Next(iterator);
            if not item {
                break;
            }
            overflow = i32(0);
            signum = PyLong_AsLongAndOverflow(item, &mut overflow);
            jacpy_release(item);
            if signum <= 0 or signum >= NSIG {
                if overflow != 0 or signum != -1 or not PyErr_Occurred() {
                    PyErr_Format(
                        PyExc_ValueError,
                        "signal number %ld out of range [1; %i]",
                        signum,
                        i32(NSIG - 1)
                    );
                }
                jacpy_release(iterator);
                return i32(0);
            }
            if sigaddset(address, i32(signum)) != 0 {
                if jacpy_errno() != EINVAL {
                    PyErr_SetFromErrno(PyExc_OSError);
                    jacpy_release(iterator);
                    return i32(0);
                }

                if PyErr_WarnFormat(
                    PyExc_RuntimeWarning,
                    1,
                    "invalid signal number %ld, please use valid_signals()",
                    signum
                )
                    != 0 {
                    jacpy_release(iterator);
                    return i32(0);
                }
            }
        }
        jacpy_release(iterator);
        return i32(0) if PyErr_Occurred() else i32(1);
    }
}

def convertenviron -> ptr[PyObject];

def posix_error -> ptr[PyObject];

def path_object_error(filename: ptr[PyObject]) -> ptr[PyObject];

def path_object_error2(
    filename: ptr[PyObject], filename2: ptr[PyObject]
) -> ptr[PyObject];

def path_error(path: path_t) -> ptr[PyObject];

def posix_path_error(path: path_t) -> ptr[PyObject];

def path_error2(path: path_t, path2: path_t) -> ptr[PyObject];

def posix_fildes_fd(fd: i32, operation: int) -> ptr[PyObject];

import from jaclang.runtime.python.modules.posix_platform { fildes_call }

import from c {
    def PyOS_FSPath(path: ptr[PyObject]) -> ptr[PyObject] {
        if jacpy_is_unicode(path) != 0 or jacpy_is_bytes(path) != 0 {
            return Py_NewRef(path);
        }
        name = interned("__fspath__");
        method = _PyObject_LookupSpecial(path, name) if name else NULL;
        jacpy_release(name);
        if not method or method == Py_None {
            jacpy_release(method);
            if PyErr_Occurred() {
                return NULL;
            }
            return PyErr_Format(
                PyExc_TypeError,
                "expected str, bytes or os.PathLike object, not %.200s",
                _PyType_Name(Py_TYPE(path))
            );
        }
        result = PyObject_CallNoArgs(method);
        jacpy_release(method);
        if not result {
            return NULL;
        }
        if jacpy_is_unicode(result) == 0 and jacpy_is_bytes(result) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                "expected %.200s.__fspath__() to return str or bytes, not %.200s",
                _PyType_Name(Py_TYPE(path)),
                _PyType_Name(Py_TYPE(result))
            );
            jacpy_release(result);
            return NULL;
        }
        return result;
    }
}

glob BEFORE_FORKERS: i64 = 0,
     AFTER_FORKERS_PARENT: i64 = 1,
     AFTER_FORKERS_CHILD: i64 = 2;

def run_at_forkers(interp: ptr[PyInterpreterState], which: i64, reverse: bool);

def register_at_forker(
    interp: ptr[PyInterpreterState], which: i64, function: ptr[PyObject]
) -> i32;

def:priv fork_child_failed(status: PyStatus) -> bool;

import from c {
    def PyOS_BeforeFork {
        interp = PyInterpreterState_Get();
        run_at_forkers(interp, BEFORE_FORKERS, True);
        _PyImport_AcquireLock(interp);
        _PyEval_StopTheWorldAll(addressof(_PyRuntime));
        jacpy_runtime_head_lock();
    }  def PyOS_AfterFork_Parent {
        jacpy_runtime_head_unlock();
        _PyEval_StartTheWorldAll(addressof(_PyRuntime));
        interp = PyInterpreterState_Get();
        _PyImport_ReleaseLock(interp);
        run_at_forkers(interp, AFTER_FORKERS_PARENT, False);
    }  def PyOS_AfterFork_Child {
        runtime = addressof(_PyRuntime);

        status = _PyRuntimeState_ReInitThreads(runtime);
        if fork_child_failed(status) {
            Py_ExitStatusException(status);
            return;
        }
        tstate = current_tstate();
        if not tstate {
            _Py_FatalErrorFunc(
                "PyOS_AfterFork_Child",
                "the function must be called with the GIL held, after Python initialization and before Python finalization, but the GIL is released (the current Python thread state is NULL)"
            );
        }
        jacpy_thread_state_native_id(tstate);

        _PyInterpreterState_ReinitRunningMain(tstate);
        status = _PyEval_ReInitThreads(tstate);
        if fork_child_failed(status) {
            Py_ExitStatusException(status);
            return;
        }
        jacpy_thread_state_fork_reset(tstate);

        others = _PyThreadState_RemoveExcept(tstate);
        _PyEval_StartTheWorldAll(runtime);
        _PyThreadState_DeleteList(others, 1);
        interp = PyThreadState_GetInterpreter(tstate);
        _PyImport_ReInitLock(interp);
        _PyImport_ReleaseLock(interp);
        _PySignal_AfterFork();
        status = _PyInterpreterState_DeleteExceptMain(runtime);
        if fork_child_failed(status) {
            Py_ExitStatusException(status);
            return;
        }
        status = _PyPerfTrampoline_AfterFork_Child();
        if fork_child_failed(status) {
            Py_ExitStatusException(status);
            return;
        }
        run_at_forkers(interp, AFTER_FORKERS_CHILD, False);
    }  def PyOS_AfterFork {
        PyOS_AfterFork_Child();
    }
}

impl PosixState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl PosixState.clear {}

impl state_object(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

impl posix_state(module: ptr[PyObject]) -> PosixState {
    state = jacpy_binding_module_native_get(module);
    if isinstance(state, PosixState) {
        return state;
    }
    raise boundary_failure();
}

impl interned(name: str) -> ptr[PyObject] {
    return jacpy_unicode_intern_text(name);
}

impl posix_module -> ptr[PyObject] {
    name = interned("posix");
    if not name {
        return NULL;
    }
    module = PyImport_GetModule(name);
    jacpy_release(name);
    return module;
}

impl fileno(stream: i32) -> i32 {
    return jacpy_stdio_fileno(stream);
}

impl id_converter(value: ptr[PyObject], kind: str) -> (u32 | None) {
    index = _PyNumber_Index(value);
    if not index {
        PyErr_Format(
            PyExc_TypeError,
            "%s should be integer, not %.200s",
            kind,
            _PyType_Name(Py_TYPE(value))
        );
        return None;
    }
    overflow = i32(0);
    result = PyLong_AsLongAndOverflow(index, &mut overflow);
    identifier = u32(0);
    failure = "";
    if overflow == 0 {
        identifier = u32.wrap(result);
        if result == -1 {
            if PyErr_Occurred() {
                jacpy_release(index);
                return None;
            }
        } elif result < 0 or i64(identifier) != result {
            failure = "less than minimum";
        }
    } elif overflow < 0 {
        failure = "less than minimum";
    } else {
        unsigned = PyLong_AsUnsignedLong(index);
        if PyErr_Occurred() {
            if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
                failure = "greater than maximum";
            } else {
                jacpy_release(index);
                return None;
            }
        } else {
            identifier = u32.wrap(unsigned);
            if identifier == u32(0xFFFFFFFF) or u64(identifier) != unsigned {
                failure = "greater than maximum";
            }
        }
    }
    jacpy_release(index);
    if failure {
        PyErr_Format(PyExc_OverflowError, "%s is %s", kind, failure);
        return None;
    }
    return identifier;
}

impl convert__Py_Uid_Converter(value: ptr[PyObject], fname: str, label: str) -> u32 {
    uid = id_converter(value, "uid");
    if uid is None {
        raise boundary_failure();
    }
    return uid;
}

impl convert__Py_Gid_Converter(value: ptr[PyObject], fname: str, label: str) -> u32 {
    gid = id_converter(value, "gid");
    if gid is None {
        raise boundary_failure();
    }
    return gid;
}

impl dev_value(device: u64) -> i64 {
    if DEV_T_SIGNED_32 {
        return i64(i32.wrap(device));
    }
    return i64.wrap(device);
}

impl _PyLong_FromDev(device: u64) -> ptr[PyObject] {
    if dev_value(device) == NODEV {
        return PyLong_FromLongLong(dev_value(device));
    }
    if DEV_T_SIGNED_32 {
        return PyLong_FromUnsignedLongLong(u64.wrap(dev_value(device)));
    }
    return PyLong_FromUnsignedLongLong(device);
}

impl return_dev_t(device: u64) -> ptr[PyObject] {
    if dev_value(device) == -1 and PyErr_Occurred() {
        return NULL;
    }
    return _PyLong_FromDev(device);
}

impl dev_converter(value: ptr[PyObject]) -> (u64 | None) {
    number = NULL;
    if jacpy_is_long(value) != 0 {
        number = Py_NewRef(value);
    } else {
        number = _PyNumber_Index(value);
        if not number {
            return None;
        }
    }
    overflow = i32(0);
    result = PyLong_AsLongLongAndOverflow(number, &mut overflow);
    if result == -1 and PyErr_Occurred() {
        jacpy_release(number);
        return None;
    }
    if overflow == 0 and result == NODEV {
        jacpy_release(number);
        return u64.wrap(NODEV);
    }
    unsigned = PyLong_AsUnsignedLongLong(number);
    jacpy_release(number);
    if unsigned == u64(0xFFFFFFFFFFFFFFFF) and PyErr_Occurred() {
        return None;
    }
    fits = unsigned <= u64(0xFFFFFFFF) if DEV_T_SIGNED_32 else True;
    if not fits {
        PyErr_Format(PyExc_OverflowError, "Python int too large to convert to C dev_t");
        return None;
    }
    return unsigned;
}

impl convert__Py_Dev_Converter(value: ptr[PyObject], fname: str, label: str) -> u64 {
    device = dev_converter(value);
    if device is None {
        raise boundary_failure();
    }
    return device;
}

impl fd_converter(value: ptr[PyObject]) -> (i32 | None) {
    if jacpy_is_bool(value) != 0 {
        if PyErr_WarnEx(PyExc_RuntimeWarning, "bool is used as a file descriptor", 1)
            != 0 {
            return None;
        }
    }
    index = _PyNumber_Index(value);
    if not index {
        return None;
    }
    overflow = i32(0);
    number = PyLong_AsLongAndOverflow(index, &mut overflow);
    jacpy_release(index);
    if overflow > 0 or number > INT_MAX {
        PyErr_Format(PyExc_OverflowError, "fd is greater than maximum");
        return None;
    }
    if overflow < 0 or number < INT_MIN {
        PyErr_Format(PyExc_OverflowError, "fd is less than minimum");
        return None;
    }
    return i32(number);
}

impl dir_fd_converter(value: ptr[PyObject]) -> (i32 | None) {
    if value == Py_None {
        return DEFAULT_DIR_FD;
    }
    if PyIndex_Check(value) != 0 {
        return fd_converter(value);
    }
    PyErr_Format(
        PyExc_TypeError,
        "argument should be integer or None, not %.200s",
        _PyType_Name(Py_TYPE(value))
    );
    return None;
}

impl argument_unavailable_error(function_name: str, argument_name: str) {
    PyErr_Format(
        PyExc_NotImplementedError,
        "%s%s%s unavailable on this platform",
        function_name,
        ": " if function_name else "",
        argument_name
    );
}

impl dir_fd_unavailable(value: ptr[PyObject]) -> (i32 | None) {
    dir_fd = dir_fd_converter(value);
    if dir_fd is None {
        return None;
    }
    if dir_fd != DEFAULT_DIR_FD {
        argument_unavailable_error("", "dir_fd");
        return None;
    }
    return dir_fd;
}

impl dir_fd_argument(value: ptr[PyObject], available: bool) -> i32 {
    dir_fd = dir_fd_converter(value) if available else dir_fd_unavailable(value);
    if dir_fd is None {
        raise boundary_failure();
    }
    return dir_fd;
}

impl convert_dir_fd_converter(value: ptr[PyObject], fname: str, label: str) -> i32 {
    return dir_fd_argument(value, True);
}

impl convert_FACCESSAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FACCESSAT));
}

impl convert_FCHMODAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FCHMODAT));
}

impl convert_FCHOWNAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FCHOWNAT));
}

impl convert_FSTATAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FSTATAT));
}

impl convert_FUTIMENSAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FUTIMESAT or HAVE_UTIMENSAT));
}

impl convert_MKDIRAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_MKDIRAT));
}

impl convert_MKFIFOAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_MKFIFOAT));
}

impl convert_MKNODAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_MKNODAT));
}

impl convert_OPENAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_OPENAT));
}

impl convert_READLINKAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_READLINKAT));
}

impl convert_SYMLINKAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_SYMLINKAT));
}

impl convert_UNLINKAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_UNLINKAT));
}

impl fd_specified(function_name: str, fd: i32) -> bool {
    if fd == -1 {
        return False;
    }
    argument_unavailable_error(function_name, "fd");
    return True;
}

impl follow_symlinks_specified(function_name: str, follow_symlinks: bool) -> bool {
    if follow_symlinks {
        return False;
    }
    argument_unavailable_error(function_name, "follow_symlinks");
    return True;
}

impl path_and_dir_fd_invalid(function_name: str, path: path_t, dir_fd: i32) -> bool {
    if not path.wide and dir_fd != DEFAULT_DIR_FD and not path.narrow {
        PyErr_Format(
            PyExc_ValueError,
            "%s: can't specify dir_fd without matching path",
            function_name
        );
        return True;
    }
    return False;
}

impl dir_fd_and_fd_invalid(function_name: str, dir_fd: i32, fd: i32) -> bool {
    if dir_fd != DEFAULT_DIR_FD and fd != -1 {
        PyErr_Format(
            PyExc_ValueError, "%s: can't specify both dir_fd and fd", function_name
        );
        return True;
    }
    return False;
}

impl fd_and_follow_symlinks_invalid(
    function_name: str, fd: i32, follow_symlinks: bool
) -> bool {
    if fd >= 0 and not follow_symlinks {
        PyErr_Format(
            PyExc_ValueError,
            "%s: cannot use fd and follow_symlinks together",
            function_name
        );
        return True;
    }
    return False;
}

impl dir_fd_and_follow_symlinks_invalid(
    function_name: str, dir_fd: i32, follow_symlinks: bool
) -> bool {
    if dir_fd != DEFAULT_DIR_FD and not follow_symlinks {
        PyErr_Format(
            PyExc_ValueError,
            "%s: cannot use dir_fd and follow_symlinks together",
            function_name
        );
        return True;
    }
    return False;
}

impl path_t.clear {
    wide = self.wide;
    self.wide = ptr();
    PyMem_Free(wide);
    held = self.object;
    self.object = NULL;
    jacpy_release(held);
    temporary = self.cleanup;
    self.cleanup = NULL;
    jacpy_release(temporary);
}

impl path_t.drop {
    self.clear();
}

impl path_t.label -> str {
    return self.argument_name or "path";
}

impl PATH_T_INITIALIZE(
    function_name: str,
    argument_name: str,
    nullable: int,
    nonstrict: int,
    make_wide: int,
    suppress_value_error: int,
    allow_fd: int
) -> path_t {
    return path_t(
        function_name=function_name,
        argument_name=argument_name,
        nullable=bool(nullable),
        nonstrict=bool(nonstrict),
        make_wide=bool(make_wide),
        suppress_value_error=bool(suppress_value_error),
        allow_fd=bool(allow_fd)
    );
}

impl PATH_T_INITIALIZE_P(
    function_name: str,
    argument_name: str,
    nullable: int,
    nonstrict: int,
    suppress_value_error: int,
    allow_fd: int
) -> path_t {
    return PATH_T_INITIALIZE(
        function_name,
        argument_name,
        nullable,
        nonstrict,
        0,
        suppress_value_error,
        allow_fd
    );
}

impl path_format_error(path: path_t, template: str) {
    PyErr_Format(
        PyExc_ValueError,
        "%s%s" + template,
        path.function_name,
        ": " if path.function_name else "",
        path.label()
    );
}

impl path_kind_text(path: path_t) -> str {
    if path.allow_fd and path.nullable {
        return "string, bytes, os.PathLike, integer or None";
    }
    if path.allow_fd {
        return "string, bytes, os.PathLike or integer";
    }
    if path.nullable {
        return "string, bytes, os.PathLike or None";
    }
    return "string, bytes or os.PathLike";
}

impl path_converter(value: ptr[PyObject], path: path_t) -> bool {
    path.object = NULL;
    path.cleanup = NULL;
    current = Py_NewRef(value);
    if current == Py_None and path.nullable {
        path.wide = ptr();
        path.narrow = ptr[u8]();
        path.fd = -1;
        return path_success(path, current, 0);
    }
    is_index = path.allow_fd and PyIndex_Check(current) != 0;
    is_bytes = jacpy_is_bytes(current) != 0;
    is_unicode = jacpy_is_unicode(current) != 0;
    if not is_index and not is_unicode and not is_bytes {
        name = interned("__fspath__");
        method = _PyObject_LookupSpecial(current, name) if name else NULL;
        jacpy_release(name);
        if not method or method == Py_None {
            jacpy_release(method);
            if PyErr_Occurred() {
                return path_failure(path, current, NULL, ptr());
            }
            return path_type_error(path, current);
        }
        result = PyObject_CallNoArgs(method);
        jacpy_release(method);
        if not result {
            return path_failure(path, current, NULL, ptr());
        }
        if jacpy_is_unicode(result) != 0 {
            is_unicode = True;
        } elif jacpy_is_bytes(result) != 0 {
            is_bytes = True;
        } else {
            PyErr_Format(
                PyExc_TypeError,
                "expected %.200s.__fspath__() to return str or bytes, not %.200s",
                _PyType_Name(Py_TYPE(current)),
                _PyType_Name(Py_TYPE(result))
            );
            jacpy_release(result);
            return path_failure(path, current, NULL, ptr());
        }
        jacpy_release(current);
        current = result;
    }
    encoded = NULL;
    if is_unicode {
        if path.make_wide {
            length = i64(0);
            wide = PyUnicode_AsWideCharString(current, &mut length);
            if not wide {
                return path_failure(path, current, NULL, ptr());
            }
            if not path.nonstrict and i64(wcslen(wide)) != length {
                path_format_error(path, "embedded null character in %s");
                return path_failure(path, current, NULL, wide);
            }
            path.wide = wide;
            path.narrow = ptr[u8]();
            path.fd = -1;
            return path_success(path, current, length);
        }
        encoded = PyUnicode_EncodeFSDefault(current);
        if not encoded {
            return path_failure(path, current, NULL, ptr());
        }
    } elif is_bytes {
        encoded = Py_NewRef(current);
    } elif is_index {
        fd = fd_converter(current);
        if fd is None {
            return path_failure(path, current, NULL, ptr());
        }
        path.fd = fd;
        path.wide = ptr();
        path.narrow = ptr[u8]();
        path.is_fd = True;
        return path_success(path, current, 0);
    } else {
        return path_type_error(path, current);
    }
    length = PyBytes_Size(encoded);
    narrow = PyBytes_AsString(encoded);
    if not path.nonstrict and i64(strlen(narrow)) != length {
        path_format_error(path, "embedded null character in %s");
        return path_failure(path, current, encoded, ptr());
    }
    if path.make_wide {
        decoded = PyUnicode_DecodeFSDefaultAndSize(narrow, length);
        if not decoded {
            return path_failure(path, current, encoded, ptr());
        }
        wide = PyUnicode_AsWideCharString(decoded, &mut length);
        jacpy_release(decoded);
        if not wide {
            return path_failure(path, current, encoded, ptr());
        }
        if not path.nonstrict and i64(wcslen(wide)) != length {
            path_format_error(path, "embedded null character in %s");
            return path_failure(path, current, encoded, wide);
        }
        path.wide = wide;
        path.narrow = ptr[u8]();
        jacpy_release(encoded);
    } else {
        path.wide = ptr();
        path.narrow = narrow;
        if encoded == current {
            jacpy_release(encoded);
        } else {
            path.cleanup = encoded;
        }
    }
    path.fd = -1;
    return path_success(path, current, length);
}

impl path_success(path: path_t, current: ptr[PyObject], length: i64) -> bool {
    path.value_error = False;
    path.length = length;
    path.object = current;
    return True;
}

impl path_type_error(path: path_t, current: ptr[PyObject]) -> bool {
    PyErr_Format(
        PyExc_TypeError,
        "%s%s%s should be %s, not %.200s",
        path.function_name,
        ": " if path.function_name else "",
        path.label(),
        path_kind_text(path),
        _PyType_Name(Py_TYPE(current))
    );
    return path_failure(path, current, NULL, ptr());
}

impl path_failure(
    path: path_t, current: ptr[PyObject], encoded: ptr[PyObject], wide: ptr
) -> bool {
    jacpy_release(current);
    jacpy_release(encoded);
    PyMem_Free(wide);
    if not path.suppress_value_error or PyErr_ExceptionMatches(PyExc_ValueError) == 0 {
        return False;
    }
    PyErr_Clear();
    path.wide = ptr();
    path.narrow = ptr[u8]();
    path.fd = -1;
    path.value_error = True;
    path.length = 0;
    path.object = NULL;
    return True;
}

impl convert_path_converter(value: ptr[PyObject], path: path_t) -> path_t {
    if not path_converter(value, path) {
        raise boundary_failure();
    }
    return path;
}

impl convert_idtype_t_converter(value: ptr[PyObject], fname: str, label: str) -> i32 {
    number = PyLong_AsInt(value);
    if number == -1 and PyErr_Occurred() {
        raise boundary_failure();
    }
    return number;
}

impl convert_id_t(value: ptr[PyObject], fname: str, label: str) -> u32 {
    number = PyLong_AsInt(value);
    if number == -1 and PyErr_Occurred() {
        raise boundary_failure();
    }
    return u32.wrap(number);
}

impl convert_Py_off_t_converter(value: ptr[PyObject], fname: str, label: str) -> i64 {
    offset = PyLong_AsLong(value);
    if PyErr_Occurred() {
        raise boundary_failure();
    }
    return offset;
}

impl PyLong_FromPy_off_t(offset: i64) -> ptr[PyObject] {
    return PyLong_FromLong(offset);
}

impl return_Py_off_t(offset: i64) -> ptr[PyObject] {
    if offset == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromPy_off_t(offset);
}

impl conv_confname(
    module: ptr[PyObject], value: ptr[PyObject], table_name: str
) -> (i32 | None) {
    current = NULL;
    if jacpy_is_unicode(value) != 0 {
        table = jacpy_object_getattr_text(module, table_name);
        if not table {
            return None;
        }
        current = PyObject_GetItem(table, value);
        jacpy_release(table);
        if not current {
            PyErr_Format(PyExc_ValueError, "unrecognized configuration name");
            return None;
        }
    } else {
        current = Py_NewRef(value);
    }
    result: (i32 | None) = None;
    if PyIndex_Check(current) == 0 {
        PyErr_Format(
            PyExc_TypeError, "configuration names must be strings or integers"
        );
    } else {
        number = PyLong_AsInt(current);
        if not (number == -1 and PyErr_Occurred()) {
            result = number;
        }
    }
    jacpy_release(current);
    return result;
}

impl convert_conv_confname(
    module: ptr[PyObject], value: ptr[PyObject], fname: str, label: str, table_name: str
) -> i32 {
    name = conv_confname(module, value, table_name);
    if name is None {
        raise boundary_failure();
    }
    return name;
}

impl convertenviron -> ptr[PyObject] {
    table = PyDict_New();
    if not table {
        return NULL;
    }
    entries = environment_table();
    if not entries {
        return table;
    }
    index = 0;
    while True {
        text = (entries + index).view(1)[0];
        if not text {
            break;
        }
        index += 1;
        total = i64(strlen(text));
        split = -1;
        for position in range(int(total)) {
            if (text + position).view(1)[0] == u8(61) {
                split = position;
                break;
            }
        }
        if split < 0 {
            continue;
        }
        key = PyBytes_FromStringAndSize(text, i64(split));
        if not key {
            jacpy_release(table);
            return NULL;
        }
        value = PyBytes_FromStringAndSize(text + (split + 1), total - i64(split) - 1);
        if not value {
            jacpy_release(key);
            jacpy_release(table);
            return NULL;
        }
        status = PyDict_SetDefaultRef(table, key, value, None);
        jacpy_release(key);
        jacpy_release(value);
        if status < 0 {
            jacpy_release(table);
            return NULL;
        }
    }
    return table;
}

impl posix_error -> ptr[PyObject] {
    return PyErr_SetFromErrno(PyExc_OSError);
}

impl path_object_error(filename: ptr[PyObject]) -> ptr[PyObject] {
    return PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, filename);
}

impl path_object_error2(
    filename: ptr[PyObject], filename2: ptr[PyObject]
) -> ptr[PyObject] {
    return PyErr_SetFromErrnoWithFilenameObjects(PyExc_OSError, filename, filename2);
}

impl path_error(path: path_t) -> ptr[PyObject] {
    return path_object_error(path.object);
}

impl posix_path_error(path: path_t) -> ptr[PyObject] {
    return path_object_error(path.object);
}

impl path_error2(path: path_t, path2: path_t) -> ptr[PyObject] {
    return path_object_error2(path.object, path2.object);
}

impl posix_fildes_fd(fd: i32, operation: int) -> ptr[PyObject] {
    while True {
        thread = PyEval_SaveThread();
        result = fildes_call(fd, operation);
        PyEval_RestoreThread(thread);
        if result == 0 {
            return Py_NewRef(Py_None);
        }
        if jacpy_errno() != EINTR {
            return posix_error();
        }
        if PyErr_CheckSignals() != 0 {
            return NULL;
        }
    }
}

impl run_at_forkers(interp: ptr[PyInterpreterState], which: i64, reverse: bool) {
    callbacks = jacpy_fork_callbacks(interp, which).view(1)[0];
    if not callbacks {
        return;
    }
    copy = PyList_GetSlice(callbacks, 0, PyList_Size(callbacks));
    if not copy {
        PyErr_FormatUnraisable(
            "Exception ignored in atfork callback while copying list %R", callbacks
        );
        return;
    }
    if reverse {
        PyList_Reverse(copy);
    }
    index = i64(0);
    while index < PyList_Size(copy) {
        function = PyList_GetItem(copy, index);
        result = PyObject_CallNoArgs(function);
        if not result {
            PyErr_FormatUnraisable("Exception ignored in atfork callback %R", function);
        } else {
            jacpy_release(result);
        }
        index += 1;
    }
    jacpy_release(copy);
}

impl register_at_forker(
    interp: ptr[PyInterpreterState], which: i64, function: ptr[PyObject]
) -> i32 {
    if not function {
        return i32(0);
    }
    slot = jacpy_fork_callbacks(interp, which);
    if not slot.view(1)[0] {
        created = PyList_New(0);
        if not created {
            return i32(-1);
        }
        slot.view(1)[0] = created;
    }
    return PyList_Append(slot.view(1)[0], function);
}

impl fork_child_failed(status: PyStatus) -> bool {
    return status._type != _PyStatus_TYPE_OK;
}
