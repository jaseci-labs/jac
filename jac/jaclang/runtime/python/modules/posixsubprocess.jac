"""A POSIX helper for the subprocess module: fork_exec().

Derived from CPython 3.14.6 Modules/_posixsubprocess.c; see ../LICENSE.cpython.
The parent converts every argument into C memory before forking: argv, envp
and the executable list as NULL-terminated char* arrays, the descriptors to
keep, the group list, the child's messages and its scratch buffers, all
reached from one child_context record. Between fork() (or vfork() on Linux)
and exec() the child runs only child_exec(): scalar and pointer arithmetic
over that record and async-signal-safe C calls, so it allocates nothing. The
one exception is the user's preexec_fn, which calls back into Python exactly
as the C module does. Platform differences are in
posixsubprocess_platform.<os>.jac.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_errno,
    jacpy_fast_item,
    jacpy_fast_size,
    jacpy_interpreter_finalizing,
    jacpy_is_bytes,
    jacpy_is_list,
    jacpy_is_long,
    jacpy_memory_copy,
    jacpy_release,
    jacpy_set_errno,
    jacpy_tuple_set_owned,
    NULL,
    _Py_Gid_Converter,
    Py_NewRef,
    _Py_RestoreSignals,
    _Py_set_inheritable_async_safe,
    _Py_Uid_Converter,
    _Py_write_noraise,
    PyBytes_AsString,
    PyBytes_FromStringAndSize,
    PyBytes_Size,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_MemoryError,
    PyExc_OSError,
    PyExc_PythonFinalizationError,
    PyExc_RuntimeError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyGC_Disable,
    PyGC_Enable,
    PyInterpreterState_Get,
    PyInterpreterState_Main,
    PyLong_AsLong,
    PyLong_FromLong,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawCalloc,
    PyMem_RawFree,
    PyMem_RawMalloc,
    PyObject,
    PyObject_Call,
    PyOS_AfterFork_Child,
    PyOS_AfterFork_Parent,
    PyOS_BeforeFork,
    PySequence_Fast,
    PySequence_GetItem,
    PySequence_Size,
    PyTuple_GetItem,
    PyTuple_New,
    PyTuple_Size,
    PyUnicode_FSConverter
}
import from jaclang.runtime.python.capi { audit_event, object_error, type_name }
import from jaclang.runtime.python.bindings.converters { borrowed_none }
import from jaclang.runtime.python.modules.posixsubprocess_constants {
    ENOENT,
    ENOTDIR,
    NGROUPS_MAX
}
import from jaclang.runtime.python.modules.posixsubprocess_platform {
    DIRENT_BUFFER_SIZE,
    FD_DIR,
    SIGACTION_SIZE,
    SIGSET_SIZE,
    VFORK_USABLE,
    block_signals,
    close_open_fds,
    reset_signal_handlers,
    set_groups,
    set_signal_mask,
    set_umask
}
import from c {
    # One 8-byte word per field: CONTEXT_WORDS below must match.
    obj child_context {
        has exec_array: ptr = ptr(),
            argv: ptr = ptr(),
            envp: ptr = ptr(),
            cwd: ptr[u8] = ptr[u8](),
            fds_to_keep: ptr[i32] = ptr[i32](),
            fds_to_keep_len: i64 = 0,
            extra_groups: ptr = ptr(),
            extra_group_size: i64 = 0,
            child_sigmask: ptr = ptr(),
            preexec_fn: ptr[PyObject] = ptr[PyObject](),
            preexec_fn_args_tuple: ptr[PyObject] = ptr[PyObject](),
            noexec: ptr[u8] = ptr[u8](),
            noexec_chdir: ptr[u8] = ptr[u8](),
            preexec_failed: ptr[u8] = ptr[u8](),
            os_error: ptr[u8] = ptr[u8](),
            subprocess_error: ptr[u8] = ptr[u8](),
            colon: ptr[u8] = ptr[u8](),
            empty: ptr[u8] = ptr[u8](),
            fd_dir: ptr[u8] = ptr[u8](),
            hex_errno: ptr[u8] = ptr[u8](),
            current_action: ptr = ptr(),
            default_action: ptr = ptr(),
            dirent_buffer: ptr = ptr(),
            p2cread: i64 = 0,
            p2cwrite: i64 = 0,
            c2pread: i64 = 0,
            c2pwrite: i64 = 0,
            errread: i64 = 0,
            errwrite: i64 = 0,
            errpipe_read: i64 = 0,
            errpipe_write: i64 = 0,
            close_fds: i64 = 0,
            restore_signals: i64 = 0,
            call_setsid: i64 = 0,
            pgid_to_set: i64 = 0,
            gid: i64 = 0,
            uid: i64 = 0,
            child_umask: i64 = 0;
    }  def close(fd: i32) -> i32;  def dup(fd: i32) -> i32;  def dup2(
        fd: i32, target: i32
    ) -> i32;  def chdir(path: ptr[u8]) -> i32;  def setsid -> i32;  def setpgid(
        pid: i32, pgid: i32
    ) -> i32;  def setregid(rgid: u32, egid: u32) -> i32;  def setreuid(
        ruid: u32, euid: u32
    ) -> i32;  def execve(path: ptr[u8], argv: ptr, envp: ptr) -> i32;  def execv(
        path: ptr[u8], argv: ptr
    ) -> i32;  def strlen(text: ptr[u8]) -> u64;  def fork -> i32;  def vfork -> i32;  def _exit(
        status: i32
    );
}

glob:priv CONTEXT_WORDS: i64 = 38,
     # sizeof(int) * 2 + 1: room for errno in hex.
     HEX_ERRNO_SIZE: i64 = 9,
     NO_ID: i64 = 0xFFFFFFFF,
     PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF;

# The error message for each way child_prepare() can fail.
glob:priv NOEXEC: i64 = 0,
     NOEXEC_CHDIR: i64 = 1,
     PREEXEC_FAILED: i64 = 2,
     # Setup finished; the exec attempts follow.
     PREPARED: i64 = 3;

# make_inheritable(): every descriptor to keep becomes inheritable, except
# errpipe_write, which stays open only until exec().
def:priv make_inheritable(record: ptr[child_context]) -> bool {
    context = record.view(1);
    index = i64(0);
    while index < context[0].fds_to_keep_len {
        fd = (context[0].fds_to_keep + index).view(1)[0];
        index += 1;
        if i64(fd) == context[0].errpipe_write {
            continue;
        }
        if _Py_set_inheritable_async_safe(fd, 1, ptr()) < 0 {
            return False;
        }
    }
    return True;
}

# The child's setup before exec(): which message reports a failure, or
# PREPARED. errno describes the failure.
def:priv child_prepare(record: ptr[child_context]) -> i64 {
    context = record.view(1);
    if not make_inheritable(record) {
        return NOEXEC;
    }
    # Close the parent's pipe ends.
    if context[0].p2cwrite != -1 and close(i32(context[0].p2cwrite)) == -1 {
        return NOEXEC;
    }
    if context[0].c2pread != -1 and close(i32(context[0].c2pread)) == -1 {
        return NOEXEC;
    }
    if context[0].errread != -1 and close(i32(context[0].errread)) == -1 {
        return NOEXEC;
    }
    if close(i32(context[0].errpipe_read)) == -1 {
        return NOEXEC;
    }
    # A pipe end dup'ed onto 0, 1 or 2 must not be overwritten (#12607).
    c2pwrite = i32(context[0].c2pwrite);
    errwrite = i32(context[0].errwrite);
    if c2pwrite == 0 {
        c2pwrite = dup(c2pwrite);
        if c2pwrite == -1 {
            return NOEXEC;
        }
        # issue32270
        if _Py_set_inheritable_async_safe(c2pwrite, 0, ptr()) < 0 {
            return NOEXEC;
        }
    }
    while errwrite == 0 or errwrite == 1 {
        errwrite = dup(errwrite);
        if errwrite == -1 {
            return NOEXEC;
        }
        if _Py_set_inheritable_async_safe(errwrite, 0, ptr()) < 0 {
            return NOEXEC;
        }
    }
    # dup2() clears FD_CLOEXEC; a no-op dup2() must be done by hand (#10806).
    p2cread = i32(context[0].p2cread);
    if p2cread == 0 {
        if _Py_set_inheritable_async_safe(p2cread, 1, ptr()) < 0 {
            return NOEXEC;
        }
    } elif p2cread != -1 and dup2(p2cread, 0) == -1 {
        return NOEXEC;
    }
    if c2pwrite == 1 {
        if _Py_set_inheritable_async_safe(c2pwrite, 1, ptr()) < 0 {
            return NOEXEC;
        }
    } elif c2pwrite != -1 and dup2(c2pwrite, 1) == -1 {
        return NOEXEC;
    }
    if errwrite == 2 {
        if _Py_set_inheritable_async_safe(errwrite, 1, ptr()) < 0 {
            return NOEXEC;
        }
    } elif errwrite != -1 and dup2(errwrite, 2) == -1 {
        return NOEXEC;
    }
    if not context[0].cwd.is_null() and chdir(context[0].cwd) == -1 {
        return NOEXEC_CHDIR;
    }
    if context[0].child_umask >= 0 {
        set_umask(i32(context[0].child_umask));
    }
    if context[0].restore_signals != 0 {
        _Py_RestoreSignals();
    }
    if VFORK_USABLE and not context[0].child_sigmask.is_null() {
        reset_signal_handlers(
            context[0].child_sigmask,
            context[0].current_action,
            context[0].default_action
        );
        status = set_signal_mask(context[0].child_sigmask);
        if status != 0 {
            jacpy_set_errno(i64(status));
            return NOEXEC;
        }
    }
    if context[0].call_setsid != 0 and setsid() == -1 {
        return NOEXEC;
    }
    if context[0].pgid_to_set >= 0 and setpgid(0, i32(context[0].pgid_to_set)) == -1 {
        return NOEXEC;
    }
    if context[0].extra_group_size >= 0
        and set_groups(context[0].extra_group_size, context[0].extra_groups) == -1 {
        return NOEXEC;
    }
    if context[0].gid != NO_ID
        and setregid(u32(context[0].gid), u32(context[0].gid)) == -1 {
        return NOEXEC;
    }
    if context[0].uid != NO_ID
        and setreuid(u32(context[0].uid), u32(context[0].uid)) == -1 {
        return NOEXEC;
    }
    if not context[0].preexec_fn.is_null()
        and not context[0].preexec_fn_args_tuple.is_null() {
        # This is where the user has asked us to deadlock their program. The
        # result is not released: exec() follows.
        result = PyObject_Call(
            context[0].preexec_fn, context[0].preexec_fn_args_tuple, NULL
        );
        if not result {
            # Stringifying the exception would allocate; report no OSError.
            jacpy_set_errno(0);
            return PREEXEC_FAILED;
        }
    }
    return PREPARED;
}

# Try each executable in turn, as Lib/os.py _execvpe() searches PATH; errno
# is the first error that is not ENOENT or ENOTDIR, else the last one.
def:priv child_execute(record: ptr[child_context]) {
    context = record.view(1);
    saved_errno = i64(0);
    executables = ptr[ptr[u8]](context[0].exec_array);
    index = i64(0);
    while True {
        executable = (executables + index).view(1)[0];
        if executable.is_null() {
            break;
        }
        index += 1;
        if not context[0].envp.is_null() {
            execve(executable, context[0].argv, context[0].envp);
        } else {
            execv(executable, context[0].argv);
        }
        error = jacpy_errno();
        if error != ENOENT and error != ENOTDIR and saved_errno == 0 {
            saved_errno = error;
        }
    }
    if saved_errno != 0 {
        jacpy_set_errno(saved_errno);
    }
}

def:priv child_write(fd: i32, text: ptr[u8]) {
    _Py_write_noraise(fd, text, strlen(text));
}

# child_exec(): runs after fork() or vfork(). Everything it reaches is in the
# child_context record, and it makes only async-signal-safe calls (plus the
# user's preexec_fn); it must not allocate. A failure before exec() is
# reported on errpipe_write as "OSError:<hex errno>:<message>" or
# "SubprocessError:0:<message>"; strerror() is not async-signal-safe, so the
# parent looks the message up.
def:priv child_exec(record: ptr[child_context]) {
    stage = child_prepare(record);
    context = record.view(1);
    message = context[0].noexec;
    if stage == NOEXEC_CHDIR {
        message = context[0].noexec_chdir;
    } elif stage == PREEXEC_FAILED {
        message = context[0].preexec_failed;
    } elif stage == PREPARED {
        message = context[0].empty;
        # Close descriptors after preexec_fn, which might open some.
        if context[0].close_fds != 0 {
            close_open_fds(
                i32(3),
                context[0].fds_to_keep,
                context[0].fds_to_keep_len,
                context[0].fd_dir,
                context[0].dirent_buffer
            );
        }
        child_execute(record);
    }
    saved_errno = jacpy_errno();
    errpipe_write = i32(context[0].errpipe_write);
    if saved_errno != 0 {
        _Py_write_noraise(errpipe_write, context[0].os_error, u64(8));
        end = context[0].hex_errno + HEX_ERRNO_SIZE;
        cursor = end;
        while saved_errno != 0 and cursor != context[0].hex_errno {
            cursor -= 1;
            digit = saved_errno % 16;
            cursor.view(1)[0] = u8(digit + 48 if digit < 10 else digit + 87);
            saved_errno = saved_errno // 16;
        }
        _Py_write_noraise(errpipe_write, cursor, u64(end - cursor));
        _Py_write_noraise(errpipe_write, context[0].colon, u64(1));
    } else {
        _Py_write_noraise(errpipe_write, context[0].subprocess_error, u64(18));
    }
    child_write(errpipe_write, message);
}

# do_fork_exec(): the parent gets the child's pid (or -1). A vfork() child
# runs on this stack while the parent is suspended, so the child never
# returns from here: it execs or exits.
def:priv do_fork_exec(record: ptr[child_context]) -> i32 {
    context = record.view(1);
    pid = i32(0);
    if VFORK_USABLE and not context[0].child_sigmask.is_null() {
        # Other threads keep running while this one waits for the child's
        # exec(); the child must not take the GIL (GH-104372).
        thread = PyEval_SaveThread();
        pid = vfork();
        if pid != 0 {
            PyEval_RestoreThread(thread);
        }
        if pid == -1 {
            # vfork() may be refused (EINVAL); fall back to fork().
            pid = fork();
        }
    } else {
        pid = fork();
    }
    if pid != 0 {
        return pid;
    }
    if not context[0].preexec_fn.is_null() {
        # preexec_fn calls back into Python, which needs this.
        PyOS_AfterFork_Child();
    }
    child_exec(record);
    _exit(255);
    return i32(0);
}

# _sanity_check_python_fd_sequence(): sorted, non-negative ints below INT_MAX.
def:priv fd_sequence_valid(fd_sequence: ptr[PyObject]) -> bool {
    previous = i64(-1);
    for index in range(int(PyTuple_Size(fd_sequence))) {
        item = PyTuple_GetItem(fd_sequence, i64(index));
        if jacpy_is_long(item) == 0 {
            return False;
        }
        fd = PyLong_AsLong(item);
        if fd < 0 or fd <= previous or fd > 2147483647 {
            return False;
        }
        previous = fd;
    }
    return True;
}

def:priv free_charp_array(array: ptr) {
    if array.is_null() {
        return;
    }
    entries = ptr[ptr[u8]](array);
    index = i64(0);
    while True {
        string = (entries + index).view(1)[0];
        if string.is_null() {
            break;
        }
        PyMem_Free(string);
        index += 1;
    }
    PyMem_Free(array);
}

# _PySequence_BytesToCharpArray(): a NULL-terminated array of copies of the
# sequence's bytes items, for argv, envp and the executable list.
def:priv bytes_to_charp_array(sequence: ptr[PyObject]) -> ptr {
    argc = PySequence_Size(sequence);
    if argc == -1 {
        return ptr();
    }
    if argc > (PY_SSIZE_T_MAX - 8) // 8 {
        PyErr_NoMemory();
        return ptr();
    }
    array = PyMem_Malloc(u64((argc + 1) * 8));
    if not array {
        PyErr_NoMemory();
        return ptr();
    }
    entries = ptr[ptr[u8]](array);
    for index in range(int(argc)) {
        slot = entries + i64(index);
        # NULL-terminate before any failure so the array can be freed.
        slot.view(1)[0] = ptr[u8]();
        item = PySequence_GetItem(sequence, i64(index));
        if not item {
            free_charp_array(array);
            return ptr();
        }
        if jacpy_is_bytes(item) == 0 {
            object_error(PyExc_TypeError, f"expected bytes, {type_name(item)} found");
            jacpy_release(item);
            free_charp_array(array);
            return ptr();
        }
        data = PyBytes_AsString(item);
        size = PyBytes_Size(item);
        if i64(strlen(data)) != size {
            object_error(PyExc_ValueError, "embedded null byte");
            jacpy_release(item);
            free_charp_array(array);
            return ptr();
        }
        copy = PyMem_Malloc(u64(size + 1));
        if not copy {
            PyErr_NoMemory();
            jacpy_release(item);
            free_charp_array(array);
            return ptr();
        }
        jacpy_memory_copy(copy, data, size + 1);
        slot.view(1)[0] = ptr[u8](copy);
        jacpy_release(item);
    }
    (entries + argc).view(1)[0] = ptr[u8]();
    return array;
}

# Everything fork_exec() holds until it returns.
obj:priv ForkState {
    has exec_array: ptr = ptr(),
        argv: ptr = ptr(),
        envp: ptr = ptr(),
        fast_args: ptr[PyObject] = NULL,
        converted_args: ptr[PyObject] = NULL,
        cwd_obj2: ptr[PyObject] = NULL,
        extra_groups: ptr = ptr(),
        c_fds_to_keep: ptr = ptr(),
        preexec_fn_args_tuple: ptr[PyObject] = NULL,
        text: ptr[PyObject] = NULL,
        scratch: ptr = ptr(),
        context: ptr = ptr(),
        need_to_reenable_gc: bool = False;

    def release {
        PyMem_Free(self.c_fds_to_keep);
        jacpy_release(self.preexec_fn_args_tuple);
        PyMem_RawFree(self.extra_groups);
        jacpy_release(self.cwd_obj2);
        free_charp_array(self.envp);
        jacpy_release(self.converted_args);
        jacpy_release(self.fast_args);
        free_charp_array(self.argv);
        free_charp_array(self.exec_array);
        jacpy_release(self.text);
        PyMem_RawFree(self.scratch);
        PyMem_RawFree(self.context);
        if self.need_to_reenable_gc {
            PyGC_Enable();
        }
    }
}

# tuple(PyUnicode_FSConverter(arg) for arg in process_args) as a char* array.
def:priv convert_args(state: ForkState, process_args: ptr[PyObject]) -> bool {
    state.fast_args = PySequence_Fast(process_args, "argv must be a tuple");
    if not state.fast_args {
        return False;
    }
    num_args = jacpy_fast_size(state.fast_args);
    state.converted_args = PyTuple_New(num_args);
    if not state.converted_args {
        return False;
    }
    for arg_num in range(int(num_args)) {
        if jacpy_fast_size(state.fast_args) != num_args {
            object_error(PyExc_RuntimeError, "args changed during iteration");
            return False;
        }
        borrowed_arg = jacpy_fast_item(state.fast_args, i64(arg_num));
        converted_arg = NULL;
        converted = PyUnicode_FSConverter(borrowed_arg, &mut converted_arg);
        jacpy_release(borrowed_arg);
        if converted == 0 {
            return False;
        }
        jacpy_tuple_set_owned(state.converted_args, i64(arg_num), converted_arg);
    }
    state.argv = bytes_to_charp_array(state.converted_args);
    jacpy_release(state.converted_args);
    state.converted_args = NULL;
    jacpy_release(state.fast_args);
    state.fast_args = NULL;
    return not state.argv.is_null();
}

# The setgroups() list; -2 (no setgroups() call) for None, -1 on error.
def:priv convert_extra_groups(state: ForkState, packed: ptr[PyObject]) -> i64 {
    if packed == borrowed_none() {
        return -2;
    }
    if jacpy_is_list(packed) == 0 {
        object_error(PyExc_TypeError, "setgroups argument must be a list");
        return -1;
    }
    size = PySequence_Size(packed);
    if size < 0 {
        return -1;
    }
    if size > NGROUPS_MAX {
        object_error(PyExc_ValueError, "too many extra_groups");
        return -1;
    }
    # extra_groups stays NULL for an empty list.
    if size > 0 {
        state.extra_groups = PyMem_RawMalloc(u64(size * 4));
        if not state.extra_groups {
            object_error(PyExc_MemoryError, "failed to allocate memory for group list");
            return -1;
        }
    }
    groups = ptr[u32](state.extra_groups);
    for index in range(int(size)) {
        element = PySequence_GetItem(packed, i64(index));
        if not element {
            return -1;
        }
        if jacpy_is_long(element) == 0 {
            object_error(PyExc_TypeError, "extra_groups must be integers");
            jacpy_release(element);
            return -1;
        }
        gid = u32(0);
        if _Py_Gid_Converter(element, &mut gid) == 0 {
            jacpy_release(element);
            object_error(PyExc_ValueError, "invalid group id");
            return -1;
        }
        (groups + i64(index)).view(1)[0] = gid;
        jacpy_release(element);
    }
    return size;
}

# The messages the child writes (the last one empty), and FD_DIR, as C
# strings in one bytes object.
def:priv child_text(state: ForkState, context: ptr[child_context]) -> bool {
    messages = [
        "noexec",
        "noexec:chdir",
        "Exception occurred in preexec_fn.",
        "OSError:",
        "SubprocessError:0:",
        ":",
        "",
        FD_DIR
    ];
    data = ("\x00".join(messages) + "\x00").encode("utf-8");
    state.text = PyBytes_FromStringAndSize(data, i64(len(data)));
    if not state.text {
        return False;
    }
    base = PyBytes_AsString(state.text);
    offsets: list[i64] = [];
    offset = i64(0);
    for message in messages {
        offsets.append(offset);
        offset += i64(len(message)) + 1;
    }
    record = context.view(1);
    record[0].noexec = base + offsets[0];
    record[0].noexec_chdir = base + offsets[1];
    record[0].preexec_failed = base + offsets[2];
    record[0].os_error = base + offsets[3];
    record[0].subprocess_error = base + offsets[4];
    record[0].colon = base + offsets[5];
    record[0].empty = base + offsets[6];
    record[0].fd_dir = base + offsets[7];
    return True;
}

# The child's scratch memory: the errno digits, two struct sigaction (the
# second zeroed: SIG_DFL), the parent's two signal sets and the directory
# buffer. Returns the two signal sets.
def:priv child_scratch(
    state: ForkState, context: ptr[child_context]
) -> tuple[ptr, ptr] {
    size = 16 + 2 * SIGACTION_SIZE + 2 * SIGSET_SIZE + DIRENT_BUFFER_SIZE;
    state.scratch = PyMem_RawCalloc(u64(1), u64(size));
    if not state.scratch {
        PyErr_NoMemory();
        return (ptr(), ptr());
    }
    base = ptr[u8](state.scratch);
    record = context.view(1);
    record[0].hex_errno = base;
    record[0].current_action = base + 16;
    record[0].default_action = base + (16 + SIGACTION_SIZE);
    all_signals: ptr = base + (16 + 2 * SIGACTION_SIZE);
    old_signals: ptr = base + (16 + 2 * SIGACTION_SIZE + SIGSET_SIZE);
    record[0].dirent_buffer = base + (16 + 2 * SIGACTION_SIZE + 2 * SIGSET_SIZE);
    return (all_signals, old_signals);
}

# fork_exec()'s arguments as the clinic converted them; pipes holds p2cread,
# p2cwrite, c2pread, c2pwrite, errread, errwrite, errpipe_read and
# errpipe_write in that order.
obj:priv ForkRequest {
    has process_args: ptr[PyObject],
        executable_list: ptr[PyObject],
        close_fds: bool,
        py_fds_to_keep: ptr[PyObject],
        cwd_obj: ptr[PyObject],
        env_list: ptr[PyObject],
        pipes: list[i32],
        restore_signals: bool,
        call_setsid: bool,
        pgid_to_set: i32,
        gid_object: ptr[PyObject],
        extra_groups_packed: ptr[PyObject],
        uid_object: ptr[PyObject],
        child_umask: i32,
        preexec_fn: ptr[PyObject];
}

def:priv fork_exec(state: ForkState, request: ForkRequest) -> i32 {
    none = borrowed_none();
    fds_to_keep_len = PyTuple_Size(request.py_fds_to_keep);
    has_preexec = request.preexec_fn != none;
    if has_preexec and jacpy_interpreter_finalizing() != 0 {
        object_error(
            PyExc_PythonFinalizationError,
            "preexec_fn not supported at interpreter shutdown"
        );
        return i32(-1);
    }
    if has_preexec and PyInterpreterState_Get() != PyInterpreterState_Main() {
        object_error(
            PyExc_RuntimeError, "preexec_fn not supported within subinterpreters"
        );
        return i32(-1);
    }
    errpipe_write = request.pipes[7];
    if request.close_fds and errpipe_write < 3 {
        object_error(PyExc_ValueError, "errpipe_write must be >= 3");
        return i32(-1);
    }
    if not fd_sequence_valid(request.py_fds_to_keep) {
        object_error(PyExc_ValueError, "bad value(s) in fds_to_keep");
        return i32(-1);
    }
    # gc must stay disabled while preexec_fn runs in the child.
    if has_preexec {
        state.need_to_reenable_gc = PyGC_Disable() != 0;
    }
    state.exec_array = bytes_to_charp_array(request.executable_list);
    if state.exec_array.is_null() {
        return i32(-1);
    }
    # Converted here: the child must not allocate.
    if request.process_args != none and not convert_args(state, request.process_args) {
        return i32(-1);
    }
    if request.env_list != none {
        state.envp = bytes_to_charp_array(request.env_list);
        if state.envp.is_null() {
            return i32(-1);
        }
    }
    cwd = ptr[u8]();
    if request.cwd_obj != none {
        cwd_obj2 = NULL;
        if PyUnicode_FSConverter(request.cwd_obj, &mut cwd_obj2) == 0 {
            return i32(-1);
        }
        state.cwd_obj2 = cwd_obj2;
        cwd = PyBytes_AsString(cwd_obj2);
    }
    extra_group_size = convert_extra_groups(state, request.extra_groups_packed);
    if extra_group_size == -1 {
        return i32(-1);
    }
    gid = u32(NO_ID);
    if request.gid_object != none
        and _Py_Gid_Converter(request.gid_object, &mut gid) == 0 {
        return i32(-1);
    }
    uid = u32(NO_ID);
    if request.uid_object != none
        and _Py_Uid_Converter(request.uid_object, &mut uid) == 0 {
        return i32(-1);
    }
    state.c_fds_to_keep = PyMem_Malloc(u64(fds_to_keep_len * 4));
    if not state.c_fds_to_keep {
        object_error(PyExc_MemoryError, "failed to malloc c_fds_to_keep");
        return i32(-1);
    }
    keep = ptr[i32](state.c_fds_to_keep);
    for index in range(int(fds_to_keep_len)) {
        fd = PyLong_AsLong(PyTuple_GetItem(request.py_fds_to_keep, i64(index)));
        if fd == -1 and PyErr_Occurred() {
            return i32(-1);
        }
        if fd < 0 or fd > 2147483647 {
            object_error(PyExc_ValueError, "fd out of range in fds_to_keep.");
            return i32(-1);
        }
        (keep + i64(index)).view(1)[0] = i32(fd);
    }
    state.context = PyMem_RawCalloc(u64(CONTEXT_WORDS), u64(8));
    if not state.context {
        PyErr_NoMemory();
        return i32(-1);
    }
    context = ptr[child_context](state.context);
    if not child_text(state, context) {
        return i32(-1);
    }
    (all_signals, old_signals) = child_scratch(state, context);
    if all_signals.is_null() {
        return i32(-1);
    }
    # The hook sees the original objects even if user classes present
    # different lists to exec().
    if not audit_event(
        "_posixsubprocess.fork_exec",
        [
            Py_NewRef(request.executable_list),
            Py_NewRef(request.process_args),
            Py_NewRef(request.env_list)
        ]
    ) {
        return i32(-1);
    }
    record = context.view(1);
    record[0].exec_array = state.exec_array;
    record[0].argv = state.argv;
    record[0].envp = state.envp;
    record[0].cwd = cwd;
    record[0].fds_to_keep = keep;
    record[0].fds_to_keep_len = fds_to_keep_len;
    record[0].extra_groups = state.extra_groups;
    record[0].extra_group_size = extra_group_size;
    record[0].p2cread = i64(request.pipes[0]);
    record[0].p2cwrite = i64(request.pipes[1]);
    record[0].c2pread = i64(request.pipes[2]);
    record[0].c2pwrite = i64(request.pipes[3]);
    record[0].errread = i64(request.pipes[4]);
    record[0].errwrite = i64(request.pipes[5]);
    record[0].errpipe_read = i64(request.pipes[6]);
    record[0].errpipe_write = i64(errpipe_write);
    record[0].close_fds = 1 if request.close_fds else 0;
    record[0].restore_signals = 1 if request.restore_signals else 0;
    record[0].call_setsid = 1 if request.call_setsid else 0;
    record[0].pgid_to_set = i64(request.pgid_to_set);
    record[0].gid = i64(gid);
    record[0].uid = i64(uid);
    record[0].child_umask = i64(request.child_umask);
    # The last step before fork(): PyOS_BeforeFork() must be matched by
    # PyOS_AfterFork_Parent() on every path from here.
    need_after_fork = False;
    if has_preexec {
        state.preexec_fn_args_tuple = PyTuple_New(0);
        if not state.preexec_fn_args_tuple {
            return i32(-1);
        }
        record[0].preexec_fn = request.preexec_fn;
        record[0].preexec_fn_args_tuple = state.preexec_fn_args_tuple;
        PyOS_BeforeFork();
        need_after_fork = True;
    }
    saved_errno = i64(0);
    # vfork() only when no credentials change and no preexec_fn runs; all
    # signals stay blocked so no handler runs in the child sharing memory.
    if VFORK_USABLE
        and not has_preexec
        and i64(uid) == NO_ID
        and i64(gid) == NO_ID
        and extra_group_size < 0 {
        status = block_signals(all_signals, old_signals);
        if status != 0 {
            saved_errno = i64(status);
        } else {
            record[0].child_sigmask = old_signals;
        }
    }
    pid = i32(-1);
    if saved_errno == 0 {
        pid = do_fork_exec(context);
        if pid == -1 {
            saved_errno = jacpy_errno();
        }
        if not record[0].child_sigmask.is_null() {
            # vfork() suspended this thread until the child's exec() or
            # exit, so the signals can be unblocked now.
            set_signal_mask(old_signals);
        }
    }
    if need_after_fork {
        PyOS_AfterFork_Parent();
    }
    if saved_errno != 0 {
        # Raised only now: PyOS_AfterFork_Parent() runs Python code.
        jacpy_set_errno(saved_errno);
        PyErr_SetFromErrno(PyExc_OSError);
        return i32(-1);
    }
    return pid;
}

def subprocess_fork_exec_impl(
    module: ptr[PyObject],
    process_args: ptr[PyObject],
    executable_list: ptr[PyObject],
    close_fds: bool,
    py_fds_to_keep: ptr[PyObject],
    cwd_obj: ptr[PyObject],
    env_list: ptr[PyObject],
    p2cread: i32,
    p2cwrite: i32,
    c2pread: i32,
    c2pwrite: i32,
    errread: i32,
    errwrite: i32,
    errpipe_read: i32,
    errpipe_write: i32,
    restore_signals: bool,
    call_setsid: bool,
    pgid_to_set: i32,
    gid_object: ptr[PyObject],
    extra_groups_packed: ptr[PyObject],
    uid_object: ptr[PyObject],
    child_umask: i32,
    preexec_fn: ptr[PyObject]
) -> ptr[PyObject] {
    state = ForkState();
    request = ForkRequest(
        process_args=process_args,
        executable_list=executable_list,
        close_fds=close_fds,
        py_fds_to_keep=py_fds_to_keep,
        cwd_obj=cwd_obj,
        env_list=env_list,
        pipes=[
            p2cread,
            p2cwrite,
            c2pread,
            c2pwrite,
            errread,
            errwrite,
            errpipe_read,
            errpipe_write
        ],
        restore_signals=restore_signals,
        call_setsid=call_setsid,
        pgid_to_set=pgid_to_set,
        gid_object=gid_object,
        extra_groups_packed=extra_groups_packed,
        uid_object=uid_object,
        child_umask=child_umask,
        preexec_fn=preexec_fn
    );
    pid = fork_exec(state, request);
    state.release();
    return NULL if pid == -1 else PyLong_FromLong(i64(pid));
}
