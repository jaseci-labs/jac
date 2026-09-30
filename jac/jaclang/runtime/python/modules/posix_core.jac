"""The posix module's shared core: path_t and the argument converters, the
error helpers, the module state and the C API other interpreter files call.

Derived from CPython 3.14.6 Modules/posixmodule.c and Modules/posixmodule.h;
see ../LICENSE.cpython. `_PyLong_FromUid`, `_PyLong_FromGid`,
`_Py_Uid_Converter`, `_Py_Gid_Converter`, `_Py_Sigset_Converter`,
`PyOS_FSPath` and the fork hooks (`PyOS_BeforeFork`, `PyOS_AfterFork_Parent`,
`PyOS_AfterFork_Child`, `PyOS_AfterFork`) are C functions under their C
names, since signalmodule.c, unicodeobject.c, _io and the interpreter call
them. The configure feature macros the C source tests are the FEATURES of
posix_constants.<os>.jac, generated from each target's pyconfig.h.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_AsString,
    PyBytes_FromStringAndSize,
    PyBytes_Size,
    PyDict_New,
    PyDict_SetDefaultRef,
    PyErr_CheckSignals,
    PyErr_Clear,
    PyErr_ExceptionMatches,
    PyErr_Format,
    PyErr_FormatUnraisable,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyErr_SetFromErrnoWithFilenameObject,
    PyErr_SetFromErrnoWithFilenameObjects,
    PyErr_WarnEx,
    PyErr_WarnFormat,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_NotImplementedError,
    PyExc_OSError,
    PyExc_OverflowError,
    PyExc_RuntimeWarning,
    PyExc_TypeError,
    PyExc_ValueError,
    PyImport_GetModule,
    PyIndex_Check,
    PyInterpreterState,
    PyInterpreterState_Get,
    PyIter_Next,
    PyList_Append,
    PyList_GetSlice,
    PyList_New,
    PyList_Reverse,
    PyList_Size,
    PyList_GetItem,
    PyLong_AsInt,
    PyLong_AsLong,
    PyLong_AsLongAndOverflow,
    PyLong_AsLongLongAndOverflow,
    PyLong_AsUnsignedLong,
    PyLong_AsUnsignedLongLong,
    PyLong_FromLong,
    PyLong_FromLongLong,
    PyLong_FromUnsignedLong,
    PyLong_FromUnsignedLongLong,
    PyMem_Free,
    PyObject,
    PyObject_CallNoArgs,
    PyObject_GetAttrString,
    PyObject_GetItem,
    PyObject_GetIter,
    PyThreadState,
    PyThreadState_GetInterpreter,
    PyThreadState_GetUnchecked,
    PyThread_get_thread_ident,
    PyUnicode_AsWideCharString,
    PyUnicode_DecodeFSDefaultAndSize,
    PyUnicode_EncodeFSDefault,
    PyUnicode_FSConverter,
    PyUnicode_InternFromString,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    _PyEval_StartTheWorldAll,
    _PyEval_StopTheWorldAll,
    _PyImport_AcquireLock,
    _PyImport_ReInitLock,
    _PyImport_ReleaseLock,
    _PyInterpreterState_ReinitRunningMain,
    _PyNumber_Index,
    _PyObject_LookupSpecial,
    _PyRuntime,
    _PyRuntimeState,
    _PySignal_AfterFork,
    _PyThreadState_DeleteList,
    _PyThreadState_RemoveExcept,
    _PyType_Name,
    jacpy_errno,
    jacpy_fork_callbacks,
    jacpy_is_bool,
    jacpy_is_bytes,
    jacpy_is_long,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_runtime_head_lock,
    jacpy_runtime_head_unlock,
    jacpy_stdio_fileno,
    jacpy_thread_state_fork_reset,
    jacpy_thread_state_native_id
}
import from jaclang.runtime.python.layouts { PyStatus, _PyStatus_TYPE_OK }
import from jaclang.runtime.python.capi { boundary_failure }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_module_native_get,
    jacpy_binding_state_get
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.modules.posix_constants {
    AT_FDCWD,
    EFD_CLOEXEC as EFD_CLOEXEC_VALUE,
    EINTR,
    EINVAL,
    HAVE_FACCESSAT,
    HAVE_FCHDIR,
    HAVE_FCHMOD,
    HAVE_FCHMODAT,
    HAVE_FCHOWN,
    HAVE_FCHOWNAT,
    HAVE_FDOPENDIR,
    HAVE_FEXECVE,
    HAVE_FPATHCONF,
    HAVE_FSTATAT,
    HAVE_FSTATVFS,
    HAVE_FTRUNCATE,
    HAVE_FUTIMENS,
    HAVE_FUTIMES,
    HAVE_FUTIMESAT,
    HAVE_MKDIRAT,
    HAVE_MKFIFOAT,
    HAVE_MKNODAT,
    HAVE_OPENAT,
    HAVE_READLINKAT,
    HAVE_SYMLINKAT,
    HAVE_UNLINKAT,
    HAVE_UTIMENSAT,
    MFD_CLOEXEC as MFD_CLOEXEC_VALUE,
    NODEV,
    NSIG
}
import from jaclang.runtime.python.modules.posix_platform {
    DEV_T_SIGNED_32,
    environment_table
}
# The interpreter's fork-time reinitializers return a PyStatus by value.
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
     # The PATH_HAVE_* allow_fd options of the clinic declarations.
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
     # The stream argument of `fileno(stdout)`, os.get_terminal_size's default.
     stdout: i32 = 1,
     INT_MAX: i64 = 2147483647,
     INT_MIN: i64 = -2147483648,
     # The object slots of the module state, in _posixstate's order.
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

# The module state's fields that are not objects.
obj PosixState(NativeState) {
    has ticks_per_second: i64 = 0,
        # The struct sequence tp_new that os.stat_result's statresult_new
        # wraps, as an address.
        statresult_new_orig: int = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
}

# A borrowed object of the module state (get_posix_state(module)->field).
def state_object(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

def posix_state(module: ptr[PyObject]) -> PosixState {
    state = jacpy_binding_module_native_get(module);
    if isinstance(state, PosixState) {
        return state;
    }
    raise boundary_failure();
}

# An interned str, a new reference (the statically allocated _Py_ID strings
# are what interning returns for these names).
def interned(name: str) -> ptr[PyObject] {
    return PyUnicode_InternFromString(name);
}

# The posix module of the running interpreter, a new reference (the
# statresult_new and scandir paths that have no module argument).
def posix_module -> ptr[PyObject] {
    name = interned("posix");
    if not name {
        return NULL;
    }
    module = PyImport_GetModule(name);
    jacpy_release(name);
    return module;
}

def fileno(stream: i32) -> i32 {
    return jacpy_stdio_fileno(stream);
}

# --- uid_t, gid_t and dev_t ------------------------------------------------

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

# _Py_Uid_Converter and _Py_Gid_Converter: uid_t and gid_t are unsigned 32
# bits, yet accept -1; `kind` is "uid" or "gid" for the messages.
def:priv id_converter(value: ptr[PyObject], kind: str) -> (u32 | None) {
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
        # The value overflowed a signed long: it may still fit unsigned.
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
            # ULONG_MAX would read as (uid_t)-1, which is not what was meant.
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

def convert__Py_Uid_Converter(value: ptr[PyObject], fname: str, label: str) -> u32 {
    uid = id_converter(value, "uid");
    if uid is None {
        raise boundary_failure();
    }
    return uid;
}

def convert__Py_Gid_Converter(value: ptr[PyObject], fname: str, label: str) -> u32 {
    gid = id_converter(value, "gid");
    if gid is None {
        raise boundary_failure();
    }
    return gid;
}

# dev_t is a signed 32-bit int on macOS and an unsigned 64-bit one on Linux;
# a dev_t travels as its bits in a u64.
def dev_value(device: u64) -> i64 {
    if DEV_T_SIGNED_32 {
        return i64(i32.wrap(device));
    }
    return i64.wrap(device);
}

def _PyLong_FromDev(device: u64) -> ptr[PyObject] {
    if dev_value(device) == NODEV {
        return PyLong_FromLongLong(dev_value(device));
    }
    if DEV_T_SIGNED_32 {
        # (unsigned long long)dev of a negative int sign-extends.
        return PyLong_FromUnsignedLongLong(u64.wrap(dev_value(device)));
    }
    return PyLong_FromUnsignedLongLong(device);
}

# The dev_t return converter (conversion_fn _PyLong_FromDev).
def return_dev_t(device: u64) -> ptr[PyObject] {
    if dev_value(device) == -1 and PyErr_Occurred() {
        return NULL;
    }
    return _PyLong_FromDev(device);
}

# _Py_Dev_Converter: a dev_t as its bits, with NODEV (-1) accepted.
def dev_converter(value: ptr[PyObject]) -> (u64 | None) {
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

def convert__Py_Dev_Converter(value: ptr[PyObject], fname: str, label: str) -> u64 {
    device = dev_converter(value);
    if device is None {
        raise boundary_failure();
    }
    return device;
}

# --- file descriptors ------------------------------------------------------

# _fd_converter: an index as a C int, warning about a bool.
def fd_converter(value: ptr[PyObject]) -> (i32 | None) {
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

def dir_fd_converter(value: ptr[PyObject]) -> (i32 | None) {
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

def argument_unavailable_error(function_name: str, argument_name: str) {
    PyErr_Format(
        PyExc_NotImplementedError,
        "%s%s%s unavailable on this platform",
        function_name,
        ": " if function_name else "",
        argument_name
    );
}

def dir_fd_unavailable(value: ptr[PyObject]) -> (i32 | None) {
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

def:priv dir_fd_argument(value: ptr[PyObject], available: bool) -> i32 {
    dir_fd = dir_fd_converter(value) if available else dir_fd_unavailable(value);
    if dir_fd is None {
        raise boundary_failure();
    }
    return dir_fd;
}

def convert_dir_fd_converter(value: ptr[PyObject], fname: str, label: str) -> i32 {
    return dir_fd_argument(value, True);
}

def convert_FACCESSAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FACCESSAT));
}

def convert_FCHMODAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FCHMODAT));
}

def convert_FCHOWNAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FCHOWNAT));
}

def convert_FSTATAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FSTATAT));
}

def convert_FUTIMENSAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_FUTIMESAT or HAVE_UTIMENSAT));
}

def convert_MKDIRAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_MKDIRAT));
}

def convert_MKFIFOAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_MKFIFOAT));
}

def convert_MKNODAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_MKNODAT));
}

def convert_OPENAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_OPENAT));
}

def convert_READLINKAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_READLINKAT));
}

def convert_SYMLINKAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_SYMLINKAT));
}

def convert_UNLINKAT_DIR_FD_CONVERTER(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    return dir_fd_argument(value, bool(HAVE_UNLINKAT));
}

def fd_specified(function_name: str, fd: i32) -> bool {
    if fd == -1 {
        return False;
    }
    argument_unavailable_error(function_name, "fd");
    return True;
}

def follow_symlinks_specified(function_name: str, follow_symlinks: bool) -> bool {
    if follow_symlinks {
        return False;
    }
    argument_unavailable_error(function_name, "follow_symlinks");
    return True;
}

def path_and_dir_fd_invalid(function_name: str, path: path_t, dir_fd: i32) -> bool {
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

def dir_fd_and_fd_invalid(function_name: str, dir_fd: i32, fd: i32) -> bool {
    if dir_fd != DEFAULT_DIR_FD and fd != -1 {
        PyErr_Format(
            PyExc_ValueError, "%s: can't specify both dir_fd and fd", function_name
        );
        return True;
    }
    return False;
}

def fd_and_follow_symlinks_invalid(
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

def dir_fd_and_follow_symlinks_invalid(
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

# --- path_t ----------------------------------------------------------------

"""A path argument as path_converter() leaves it. Input fields configure the
conversion; at most one of `wide` (a PyMem wchar_t string it owns) and
`narrow` (the bytes of `object` or `cleanup`) is set, and neither when the
path is None or a descriptor. Dropping it is path_cleanup()."""
obj path_t {
    # Input fields: "" stands for a NULL function or argument name.
    has function_name: str = "",
        argument_name: str = "",
        nullable: bool = False,
        nonstrict: bool = False,
        make_wide: bool = False,
        suppress_value_error: bool = False,
        allow_fd: bool = False,
        # Output fields.
        wide: ptr = ptr(),
        narrow: ptr[u8] = ptr[u8](),
        fd: i32 = -1,
        is_fd: bool = False,
        value_error: bool = False,
        length: i64 = 0,
        object: ptr[PyObject] = ptr[PyObject](),
        cleanup: ptr[PyObject] = ptr[PyObject]();

    def clear {
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

    def drop {
        self.clear();
    }

    # The name error messages use: argument_name, or "path" for NULL.
    def label -> str {
        return self.argument_name if self.argument_name else "path";
    }
}

def PATH_T_INITIALIZE(
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

def PATH_T_INITIALIZE_P(
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

def:priv path_format_error(path: path_t, template: str) {
    PyErr_Format(
        PyExc_ValueError,
        "%s%s" + template,
        path.function_name,
        ": " if path.function_name else "",
        path.label()
    );
}

def:priv path_kind_text(path: path_t) -> str {
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

# path_converter(): fill `path` from `value`; False with the exception set on
# failure. A ValueError is swallowed into value_error when
# suppress_value_error is set.
def path_converter(value: ptr[PyObject], path: path_t) -> bool {
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
        # PyOS_FSPath() inlined for its messages.
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
            # path.object keeps the bytes alive.
            jacpy_release(encoded);
        } else {
            path.cleanup = encoded;
        }
    }
    path.fd = -1;
    return path_success(path, current, length);
}

def:priv path_success(path: path_t, current: ptr[PyObject], length: i64) -> bool {
    path.value_error = False;
    path.length = length;
    path.object = current;
    return True;
}

def:priv path_type_error(path: path_t, current: ptr[PyObject]) -> bool {
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

def:priv path_failure(
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

def convert_path_converter(value: ptr[PyObject], path: path_t) -> path_t {
    if not path_converter(value, path) {
        raise boundary_failure();
    }
    return path;
}

# --- other converters ------------------------------------------------------

# idtype_t_converter
def convert_idtype_t_converter(value: ptr[PyObject], fname: str, label: str) -> i32 {
    number = PyLong_AsInt(value);
    if number == -1 and PyErr_Occurred() {
        raise boundary_failure();
    }
    return number;
}

# The id_t converter: (id_t)PyLong_AsPid(), pid_t being int.
def convert_id_t(value: ptr[PyObject], fname: str, label: str) -> u32 {
    number = PyLong_AsInt(value);
    if number == -1 and PyErr_Occurred() {
        raise boundary_failure();
    }
    return u32.wrap(number);
}

# Py_off_t_converter: off_t is a long on every supported target.
def convert_Py_off_t_converter(value: ptr[PyObject], fname: str, label: str) -> i64 {
    offset = PyLong_AsLong(value);
    if PyErr_Occurred() {
        raise boundary_failure();
    }
    return offset;
}

def PyLong_FromPy_off_t(offset: i64) -> ptr[PyObject] {
    return PyLong_FromLong(offset);
}

# The Py_off_t return converter (conversion_fn PyLong_FromPy_off_t).
def return_Py_off_t(offset: i64) -> ptr[PyObject] {
    if offset == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromPy_off_t(offset);
}

# object(converter='PyUnicode_FSConverter'): the argument's bytes, a new
# reference the glue's OwnedReference releases.
def convert_PyUnicode_FSConverter(
    value: ptr[PyObject], fname: str, label: str
) -> ptr[PyObject] {
    converted = NULL;
    if PyUnicode_FSConverter(value, &mut converted) == 0 {
        raise boundary_failure();
    }
    return converted;
}

# conv_confname(): a configuration name (a key of the module's `table_name`
# dict) or an integer, as a C int.
def conv_confname(
    module: ptr[PyObject], value: ptr[PyObject], table_name: str
) -> (i32 | None) {
    current = NULL;
    if jacpy_is_unicode(value) != 0 {
        table = PyObject_GetAttrString(module, table_name);
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

def convert_conv_confname(
    module: ptr[PyObject], value: ptr[PyObject], fname: str, label: str, table_name: str
) -> i32 {
    name = conv_confname(module, value, table_name);
    if name is None {
        raise boundary_failure();
    }
    return name;
}

# --- signal sets -----------------------------------------------------------

import from c {
    # An iterable of signal numbers as a sigset_t; 1 on success.
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
                # range(1, NSIG) is allowed, with a warning for the holes.
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

# --- environ ---------------------------------------------------------------

# convertenviron(): the environment as a dict of bytes, first definition of
# a name winning.
def convertenviron -> ptr[PyObject] {
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

# --- errors ----------------------------------------------------------------

def posix_error -> ptr[PyObject] {
    return PyErr_SetFromErrno(PyExc_OSError);
}

def path_object_error(filename: ptr[PyObject]) -> ptr[PyObject] {
    return PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, filename);
}

def path_object_error2(
    filename: ptr[PyObject], filename2: ptr[PyObject]
) -> ptr[PyObject] {
    return PyErr_SetFromErrnoWithFilenameObjects(PyExc_OSError, filename, filename2);
}

def path_error(path: path_t) -> ptr[PyObject] {
    return path_object_error(path.object);
}

def posix_path_error(path: path_t) -> ptr[PyObject] {
    return path_object_error(path.object);
}

def path_error2(path: path_t, path2: path_t) -> ptr[PyObject] {
    return path_object_error2(path.object, path2.object);
}

# posix_fildes_fd(): call `operation` (0 fsync, 1 fdatasync, 2 fchdir) on fd
# with the GIL released, retrying on EINTR unless a signal handler raises.
def posix_fildes_fd(fd: i32, operation: int) -> ptr[PyObject] {
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

import from jaclang.runtime.python.modules.posix_platform { fildes_call }

# --- os.fspath -------------------------------------------------------------

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

# --- fork hooks ------------------------------------------------------------

glob BEFORE_FORKERS: i64 = 0,
     AFTER_FORKERS_PARENT: i64 = 1,
     AFTER_FORKERS_CHILD: i64 = 2;

# run_at_forkers(): call each callback of the list at `which`, newest first
# when `reverse`, on a copy so a callback may register another.
def run_at_forkers(interp: ptr[PyInterpreterState], which: i64, reverse: bool) {
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

# register_at_forker(): append `function` to the list at `which`, making the
# list on first use; NULL registers nothing.
def register_at_forker(
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

def:priv fork_child_failed(status: PyStatus) -> bool {
    return status._type != _PyStatus_TYPE_OK;
}

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
        # Re-creates runtime->interpreters.mutex (HEAD_UNLOCK).
        status = _PyRuntimeState_ReInitThreads(runtime);
        if fork_child_failed(status) {
            Py_ExitStatusException(status);
            return;
        }
        tstate = PyThreadState_GetUnchecked();
        if not tstate {
            _Py_FatalErrorFunc(
                "PyOS_AfterFork_Child",
                "the function must be called with the GIL held, after Python initialization and before Python finalization, but the GIL is released (the current Python thread state is NULL)"
            );
        }
        jacpy_thread_state_native_id(tstate);
        # Ideally we could guarantee tstate is running main.
        _PyInterpreterState_ReinitRunningMain(tstate);
        status = _PyEval_ReInitThreads(tstate);
        if fork_child_failed(status) {
            Py_ExitStatusException(status);
            return;
        }
        jacpy_thread_state_fork_reset(tstate);
        # Start the world once this is the only thread state left, before
        # deleting the others (which may run destructors).
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
    }
    # Legacy wrapper.
    def PyOS_AfterFork {
        PyOS_AfterFork_Child();
    }
}
