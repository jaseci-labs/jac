"""The posix module's process identity and system information functions: user,
group, process group and session ids, login name, uname, strerror, random
bytes, CPU count, sysconf/confstr, the environment and the input hook.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
What differs between macOS and Linux (getgrouplist/initgroups argument types,
setgroups' count, the setresuid family, struct utsname, the login name buffer
and the getrandom system call) lives in posix_ids_platform.<os>.jac.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_AsString,
    PyBytes_FromStringAndSize,
    PyBytes_Size,
    PyConfig_GetInt,
    PyErr_CheckSignals,
    PyErr_NoMemory,
    PyErr_SetFromErrno,
    PyErr_SetString,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_OSError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyIndex_Check,
    PyList_New,
    PyList_SetItem,
    PyLong_FromLong,
    PyLong_FromUnsignedLong,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PySequence_Check,
    PySequence_GetItem,
    PySequence_Size,
    PySys_Audit,
    PyUnicode_DecodeFSDefault,
    PyUnicode_DecodeFSDefaultAndSize,
    PyUnicode_DecodeLocale,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    _PyBytes_Resize,
    _PyOS_URandom,
    jacpy_errno,
    jacpy_release,
    jacpy_set_errno
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.module { add_state_owned }
import from jaclang.runtime.python.bindings.type { struct_sequence_type }
import from jaclang.runtime.python.object_model.structseq {
    PyStructSequence_New,
    PyStructSequence_SetItem
}
import from jaclang.runtime.python.modules.posix_constants {
    EINTR,
    EINVAL,
    HAVE_BROKEN_UNSETENV,
    NGROUPS_MAX,
    _SC_NPROCESSORS_ONLN
}
import from jaclang.runtime.python.modules.posix_core {
    INT_MAX,
    STATE_UNAME_RESULT_TYPE,
    PyOS_FSPath,
    _PyLong_FromGid,
    _PyLong_FromUid,
    _Py_Gid_Converter,
    convertenviron,
    posix_error,
    state_object
}
import from jaclang.runtime.python.modules.posix_ids_platform {
    LOGIN_NAME_SIZE,
    UTSNAME_FIELD_SIZE,
    UTSNAME_SIZE,
    getgrouplist_darwin,
    getgrouplist_linux,
    get_res_gid,
    get_res_uid,
    getrandom_syscall,
    initgroups_darwin,
    initgroups_linux,
    set_groups,
    setresgid,
    setresuid
}

import from c {
    def getegid -> u32;  def geteuid -> u32;  def getgid -> u32;  def getuid -> u32;  def getpid -> i32;  def getppid -> i32;  def getpgid(
        pid: i32
    ) -> i32;  def getpgrp -> i32;  def setpgrp -> i32;  def setpgid(
        pid: i32, pgrp: i32
    ) -> i32;  def getsid(pid: i32) -> i32;  def setsid -> i32;  def tcgetpgrp(
        fd: i32
    ) -> i32;  def tcsetpgrp(fd: i32, pgid: i32) -> i32;  def setuid(uid: u32) -> i32;  def seteuid(
        euid: u32
    ) -> i32;  def setgid(gid: u32) -> i32;  def setegid(egid: u32) -> i32;  def setreuid(
        ruid: u32, euid: u32
    ) -> i32;  def setregid(rgid: u32, egid: u32) -> i32;  def getgroups(
        count: i32, groups: ptr[u32]
    ) -> i32;  def getlogin_r(name: ptr[u8], size: u64) -> i32;  def uname(
        name: ptr
    ) -> i32;  def strerror(code: i32) -> ptr[u8];  def sysconf(name: i32) -> i64;  def confstr(
        name: i32, buffer: ptr[u8], size: u64
    ) -> u64;  def setenv(name: ptr[u8], value: ptr[u8], overwrite: i32) -> i32;  def unsetenv(
        name: ptr[u8]
    ) -> i32;  def strchr(text: ptr[u8], character: i32) -> ptr[u8];
    # int (*PyOS_InputHook)(void), read in place.
    obj InputHook {
        has hook: Callable[[], i32];
    }  glob PyOS_InputHook: InputHook;
}

# MAX_GROUPS: NGROUPS_MAX is defined on every supported target.
glob:priv MAX_GROUPS: i64 = NGROUPS_MAX,
     GID_SIZE: u64 = 4,
     CONFSTR_BUFFER_SIZE: u64 = 255;

glob:priv UNAME_RESULT_DOC: str = "uname_result: Result from os.uname().\n\n"
         + "This object may be accessed either as a tuple of\n"
         + "  (sysname, nodename, release, version, machine),\n"
         + "or via the attributes sysname, nodename, release, version, and machine.\n"
         + "\n"
         + "See os.uname for more information.";

def posix_ids_exec(module: ptr[PyObject]) -> bool {
    result_type = struct_sequence_type(
        "posix.uname_result",
        UNAME_RESULT_DOC,
        [
            ("sysname", "operating system name"),
            ("nodename", "name of machine on network (implementation-defined)"),
            ("release", "operating system release"),
            ("version", "operating system version"),
            ("machine", "hardware identifier")
        ],
        5
    );
    return add_state_owned(
        module, STATE_UNAME_RESULT_TYPE, "uname_result", result_type
    );
}

# --- user, group and process ids --------------------------------------------

def os_getegid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return _PyLong_FromGid(getegid());
}

def os_geteuid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return _PyLong_FromUid(geteuid());
}

def os_getgid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return _PyLong_FromGid(getgid());
}

def os_getuid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return _PyLong_FromUid(getuid());
}

def os_getpid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(getpid()));
}

def os_getppid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(getppid()));
}

def os_getpgid_impl(module: ptr[PyObject], pid: i32) -> ptr[PyObject] {
    pgid = getpgid(pid);
    if pgid < 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(pgid));
}

def os_getpgrp_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(getpgrp()));
}

def os_setpgrp_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    if setpgrp() < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_setpgid_impl(module: ptr[PyObject], pid: i32, pgrp: i32) -> ptr[PyObject] {
    if setpgid(pid, pgrp) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_getsid_impl(module: ptr[PyObject], pid: i32) -> ptr[PyObject] {
    sid = getsid(pid);
    if sid < 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(sid));
}

def os_setsid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    if setsid() < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_tcgetpgrp_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    pgid = tcgetpgrp(fd);
    if pgid < 0 {
        return posix_error();
    }
    return PyLong_FromLong(i64(pgid));
}

def os_tcsetpgrp_impl(module: ptr[PyObject], fd: i32, pgid: i32) -> ptr[PyObject] {
    if tcsetpgrp(fd, pgid) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_setuid_impl(module: ptr[PyObject], uid: u32) -> ptr[PyObject] {
    if setuid(uid) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_seteuid_impl(module: ptr[PyObject], euid: u32) -> ptr[PyObject] {
    if seteuid(euid) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_setegid_impl(module: ptr[PyObject], egid: u32) -> ptr[PyObject] {
    if setegid(egid) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_setreuid_impl(module: ptr[PyObject], ruid: u32, euid: u32) -> ptr[PyObject] {
    if setreuid(ruid, euid) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_setregid_impl(module: ptr[PyObject], rgid: u32, egid: u32) -> ptr[PyObject] {
    if setregid(rgid, egid) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_setgid_impl(module: ptr[PyObject], gid: u32) -> ptr[PyObject] {
    if setgid(gid) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_setresuid_impl(
    module: ptr[PyObject], ruid: u32, euid: u32, suid: u32
) -> ptr[PyObject] {
    if setresuid(ruid, euid, suid) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_setresgid_impl(
    module: ptr[PyObject], rgid: u32, egid: u32, sgid: u32
) -> ptr[PyObject] {
    if setresgid(rgid, egid, sgid) < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_getresuid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    (result, ruid, euid, suid) = get_res_uid();
    if result < 0 {
        return posix_error();
    }
    return Py_BuildValue(
        "(NNN)", _PyLong_FromUid(ruid), _PyLong_FromUid(euid), _PyLong_FromUid(suid)
    );
}

def os_getresgid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    (result, rgid, egid, sgid) = get_res_gid();
    if result < 0 {
        return posix_error();
    }
    return Py_BuildValue(
        "(NNN)", _PyLong_FromGid(rgid), _PyLong_FromGid(egid), _PyLong_FromGid(sgid)
    );
}

# --- supplementary groups ---------------------------------------------------

# os.getgrouplist() on macOS: the group is an int and the list holds ints,
# each converted as (unsigned long)groups[i].
def os_getgrouplist_darwin_impl(
    module: ptr[PyObject], user: str, basegid: i32
) -> ptr[PyObject] {
    # One more than NGROUPS_MAX: getgrouplist() also returns the primary group.
    ngroups = i32(1 + MAX_GROUPS);
    groups = ptr[i32]();
    while True {
        groups = ptr[i32](PyMem_Malloc(u64(ngroups) * GID_SIZE));
        if not groups {
            return PyErr_NoMemory();
        }
        old_ngroups = ngroups;
        (result, ngroups) = getgrouplist_darwin(user, basegid, groups, ngroups);
        if result != -1 {
            break;
        }
        # getgrouplist() fails if the group list is too small.
        PyMem_Free(groups);
        # glibc sets ngroups to the total when the list is too small; otherwise
        # double it.
        if ngroups <= old_ngroups {
            if i64(ngroups) > INT_MAX / 2 {
                return PyErr_NoMemory();
            }
            ngroups *= 2;
        }
    }
    list = PyList_New(i64(ngroups));
    if not list {
        PyMem_Free(groups);
        return NULL;
    }
    for index in range(int(ngroups)) {
        item = PyLong_FromUnsignedLong(u64.wrap(i64((groups + index).view(1)[0])));
        if not item {
            jacpy_release(list);
            PyMem_Free(groups);
            return NULL;
        }
        PyList_SetItem(list, i64(index), item);
    }
    PyMem_Free(groups);
    return list;
}

# os.getgrouplist() elsewhere: the group and the list are gid_t.
def os_getgrouplist_linux_impl(
    module: ptr[PyObject], user: str, basegid: u32
) -> ptr[PyObject] {
    ngroups = i32(1 + MAX_GROUPS);
    groups = ptr[u32]();
    while True {
        groups = ptr[u32](PyMem_Malloc(u64(ngroups) * GID_SIZE));
        if not groups {
            return PyErr_NoMemory();
        }
        old_ngroups = ngroups;
        (result, ngroups) = getgrouplist_linux(user, basegid, groups, ngroups);
        if result != -1 {
            break;
        }
        PyMem_Free(groups);
        if ngroups <= old_ngroups {
            if i64(ngroups) > INT_MAX / 2 {
                return PyErr_NoMemory();
            }
            ngroups *= 2;
        }
    }
    list = PyList_New(i64(ngroups));
    if not list {
        PyMem_Free(groups);
        return NULL;
    }
    for index in range(int(ngroups)) {
        item = _PyLong_FromGid((groups + index).view(1)[0]);
        if not item {
            jacpy_release(list);
            PyMem_Free(groups);
            return NULL;
        }
        PyList_SetItem(list, i64(index), item);
    }
    PyMem_Free(groups);
    return list;
}

def os_getgroups_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    # A zero length asks for the number of groups.
    n = getgroups(i32(0), ptr[u32]());
    if n < 0 {
        return posix_error();
    }
    if n == 0 {
        return PyList_New(0);
    }
    grouplist = ptr[u32](PyMem_Malloc(u64(n) * GID_SIZE));
    if not grouplist {
        return PyErr_NoMemory();
    }
    n = getgroups(n, grouplist);
    if n == -1 {
        posix_error();
        PyMem_Free(grouplist);
        return NULL;
    }
    result = PyList_New(i64(n));
    if not result {
        PyMem_Free(grouplist);
        return NULL;
    }
    for index in range(int(n)) {
        group = _PyLong_FromGid((grouplist + index).view(1)[0]);
        if not group {
            PyMem_Free(grouplist);
            jacpy_release(result);
            return NULL;
        }
        PyList_SetItem(result, i64(index), group);
    }
    PyMem_Free(grouplist);
    return result;
}

def os_setgroups_impl(module: ptr[PyObject], groups: ptr[PyObject]) -> ptr[PyObject] {
    if PySequence_Check(groups) == 0 {
        PyErr_SetString(PyExc_TypeError, "setgroups argument must be a sequence");
        return NULL;
    }
    length = PySequence_Size(groups);
    if length < 0 {
        return NULL;
    }
    if length > MAX_GROUPS {
        PyErr_SetString(PyExc_ValueError, "too many groups");
        return NULL;
    }
    grouplist = ptr[u32](PyMem_Malloc(u64(length) * GID_SIZE));
    if not grouplist {
        PyErr_NoMemory();
        return NULL;
    }
    index = i64(0);
    while index < length {
        elem = PySequence_GetItem(groups, index);
        if not elem {
            PyMem_Free(grouplist);
            return NULL;
        }
        if PyIndex_Check(elem) == 0 {
            PyErr_SetString(PyExc_TypeError, "groups must be integers");
            jacpy_release(elem);
            PyMem_Free(grouplist);
            return NULL;
        }
        if _Py_Gid_Converter(elem, grouplist + index) == 0 {
            jacpy_release(elem);
            PyMem_Free(grouplist);
            return NULL;
        }
        jacpy_release(elem);
        index += 1;
    }
    if set_groups(length, grouplist) < 0 {
        posix_error();
        PyMem_Free(grouplist);
        return NULL;
    }
    PyMem_Free(grouplist);
    return Py_NewRef(Py_None);
}

def os_initgroups_darwin_impl(
    module: ptr[PyObject], oname: ptr[PyObject], gid: i32
) -> ptr[PyObject] {
    username = PyBytes_AsString(oname);
    if initgroups_darwin(username, gid) == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return Py_NewRef(Py_None);
}

def os_initgroups_linux_impl(
    module: ptr[PyObject], oname: ptr[PyObject], gid: u32
) -> ptr[PyObject] {
    username = PyBytes_AsString(oname);
    if initgroups_linux(username, gid) == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return Py_NewRef(Py_None);
}

# --- login name and system identification -----------------------------------

# HAVE_GETLOGIN_R: the name buffer is MAXLOGNAME + 1 or UT_NAMESIZE + 1 bytes.
def os_getlogin_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    result = NULL;
    name = ptr[u8](PyMem_Malloc(u64(LOGIN_NAME_SIZE)));
    if not name {
        return PyErr_NoMemory();
    }
    err = getlogin_r(name, u64(LOGIN_NAME_SIZE));
    if err != 0 {
        old_errno = jacpy_errno();
        jacpy_set_errno(-i64(err));
        posix_error();
        jacpy_set_errno(old_errno);
    } else {
        result = PyUnicode_DecodeFSDefault(name);
    }
    PyMem_Free(name);
    return result;
}

def os_uname_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    names = ptr[u8](PyMem_Malloc(u64(UTSNAME_SIZE)));
    if not names {
        return PyErr_NoMemory();
    }
    thread = PyEval_SaveThread();
    res = uname(names);
    PyEval_RestoreThread(thread);
    if res < 0 {
        posix_error();
        PyMem_Free(names);
        return NULL;
    }
    value = PyStructSequence_New(state_object(module, STATE_UNAME_RESULT_TYPE));
    if not value {
        PyMem_Free(names);
        return NULL;
    }
    # sysname, nodename, release, version and machine, in field order.
    for index in range(5) {
        field = PyUnicode_DecodeFSDefault(names + i64(index) * UTSNAME_FIELD_SIZE);
        if not field {
            jacpy_release(value);
            PyMem_Free(names);
            return NULL;
        }
        PyStructSequence_SetItem(value, i64(index), field);
    }
    PyMem_Free(names);
    return value;
}

def os_strerror_impl(module: ptr[PyObject], code: i32) -> ptr[PyObject] {
    message = strerror(code);
    if not message {
        PyErr_SetString(PyExc_ValueError, "strerror() argument out of range");
        return NULL;
    }
    return PyUnicode_DecodeLocale(ptr(message), ptr[u8]("surrogateescape"));
}

# --- random bytes -----------------------------------------------------------

def os_urandom_impl(module: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if size < 0 {
        PyErr_SetString(PyExc_ValueError, "negative argument not allowed");
        return NULL;
    }
    bytes = PyBytes_FromStringAndSize(ptr[u8](), size);
    if not bytes {
        return NULL;
    }
    result = _PyOS_URandom(ptr(PyBytes_AsString(bytes)), PyBytes_Size(bytes));
    if result == -1 {
        jacpy_release(bytes);
        return NULL;
    }
    return bytes;
}

# HAVE_GETRANDOM_SYSCALL: the binding installs it only on Linux.
def os_getrandom_impl(module: ptr[PyObject], size: i64, flags: i32) -> ptr[PyObject] {
    if size < 0 {
        jacpy_set_errno(EINVAL);
        return posix_error();
    }
    bytes = PyBytes_FromStringAndSize(ptr[u8](), size);
    if not bytes {
        PyErr_NoMemory();
        return NULL;
    }
    n = i64(0);
    while True {
        n = getrandom_syscall(ptr(PyBytes_AsString(bytes)), PyBytes_Size(bytes), flags);
        if n < 0 and jacpy_errno() == EINTR {
            if PyErr_CheckSignals() < 0 {
                jacpy_release(bytes);
                return NULL;
            }
            # getrandom() was interrupted by a signal: retry.
            continue;
        }
        break;
    }
    if n < 0 {
        PyErr_SetFromErrno(PyExc_OSError);
        jacpy_release(bytes);
        return NULL;
    }
    if n != size {
        _PyBytes_Resize(&mut bytes, n);
    }
    return bytes;
}

# --- system configuration ---------------------------------------------------

def os_cpu_count_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    # config->cpu_count: -X cpu_count or PYTHON_CPU_COUNT, -1 when unset.
    cpu_count = i32(0);
    if PyConfig_GetInt("cpu_count", &mut cpu_count) < 0 {
        return NULL;
    }
    if cpu_count > 0 {
        return PyLong_FromLong(i64(cpu_count));
    }
    ncpu = i32.wrap(sysconf(i32(_SC_NPROCESSORS_ONLN)));
    if ncpu < 1 {
        return Py_NewRef(Py_None);
    }
    return PyLong_FromLong(i64(ncpu));
}

def os_sysconf_impl(module: ptr[PyObject], name: i32) -> i64 {
    jacpy_set_errno(0);
    value = sysconf(name);
    if value == -1 and jacpy_errno() != 0 {
        posix_error();
    }
    return value;
}

def os_confstr_impl(module: ptr[PyObject], name: i32) -> ptr[PyObject] {
    buffer = ptr[u8](PyMem_Malloc(CONFSTR_BUFFER_SIZE));
    if not buffer {
        return PyErr_NoMemory();
    }
    jacpy_set_errno(0);
    length = confstr(name, buffer, CONFSTR_BUFFER_SIZE);
    if length == 0 {
        if jacpy_errno() != 0 {
            posix_error();
            PyMem_Free(buffer);
            return NULL;
        }
        PyMem_Free(buffer);
        return Py_NewRef(Py_None);
    }
    result = NULL;
    if length >= CONFSTR_BUFFER_SIZE {
        large = ptr[u8](PyMem_Malloc(length));
        if not large {
            PyMem_Free(buffer);
            return PyErr_NoMemory();
        }
        length2 = confstr(name, large, length);
        result = PyUnicode_DecodeFSDefaultAndSize(large, i64(length2) - 1);
        PyMem_Free(large);
    } else {
        result = PyUnicode_DecodeFSDefaultAndSize(buffer, i64(length) - 1);
    }
    PyMem_Free(buffer);
    return result;
}

# --- the environment --------------------------------------------------------

def os_putenv_impl(
    module: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    name_string = PyBytes_AsString(name);
    value_string = PyBytes_AsString(value);
    if strchr(name_string, i32(61)) {
        PyErr_SetString(PyExc_ValueError, "illegal environment variable name");
        return NULL;
    }
    if PySys_Audit("os.putenv", "OO", name, value) < 0 {
        return NULL;
    }
    if setenv(name_string, value_string, i32(1)) != 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_unsetenv_impl(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    if PySys_Audit("os.unsetenv", "(O)", name) < 0 {
        return NULL;
    }
    if HAVE_BROKEN_UNSETENV {
        unsetenv(PyBytes_AsString(name));
    } else {
        err = unsetenv(PyBytes_AsString(name));
        if err != 0 {
            return posix_error();
        }
    }
    return Py_NewRef(Py_None);
}

def os__create_environ_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return convertenviron();
}

def os_fspath_impl(module: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    return PyOS_FSPath(path);
}

# --- the input hook ---------------------------------------------------------

def os__inputhook_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    result = i32(0);
    slot = addressof(PyOS_InputHook).view(1);
    if int(slot[0].hook) != 0 {
        thread = PyEval_SaveThread();
        result = slot[0].hook();
        PyEval_RestoreThread(thread);
    }
    return PyLong_FromLong(i64(result));
}

def os__is_inputhook_installed_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    installed = int(addressof(PyOS_InputHook).view(1)[0].hook) != 0;
    return PyBool_FromLong(i64(1 if installed else 0));
}
