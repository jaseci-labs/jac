"""Waiting for I/O readiness: select(), poll(), epoll and kqueue.

Derived from CPython 3.14.6 Modules/selectmodule.c; see ../LICENSE.cpython.
The system calls and their records come from select_platform.<os>.jac (epoll
on Linux, kqueue on macOS) and the constants from select_constants.<os>.jac.
fd_set is addressed as FD_SETSIZE bits in memory order, which is the layout
of every little-endian target. No supported target has Solaris'
<sys/devpoll.h>: the devpoll implementations the clinic glue names report
that and the module never publishes them.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_dict_size,
    jacpy_errno,
    jacpy_fast_item,
    jacpy_fast_size,
    jacpy_release,
    jacpy_set_errno,
    jacpy_tuple_set_owned,
    NULL,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    _Py_set_inheritable,
    Py_TYPE,
    _PyDeadline_Get,
    _PyDeadline_Init,
    PyDict_Contains,
    PyDict_DelItem,
    PyDict_New,
    PyDict_Next,
    PyDict_SetItem,
    PyErr_CheckSignals,
    PyErr_ExceptionMatches,
    PyErr_GetRaisedException,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyErr_SetRaisedException,
    PyErr_WarnEx,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_OSError,
    PyExc_OverflowError,
    PyExc_RuntimeError,
    PyExc_RuntimeWarning,
    PyExc_SystemError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyImport_ImportModuleAttrString,
    PyIndex_Check,
    PyList_New,
    PyList_SetItem,
    PyLong_AsLong,
    PyLong_AsNativeBytes,
    PyLong_FromLong,
    PyLong_FromUnsignedLong,
    PyMem_Calloc,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_Realloc,
    PyObject,
    PyObject_AsFileDescriptor,
    PyObject_Call,
    PyObject_CallNoArgs,
    PyObject_GetAttr,
    PyObject_Str,
    PySequence_Fast,
    _PyTime_AsMilliseconds,
    _PyTime_AsTimespec,
    _PyTime_AsTimeval,
    _PyTime_AsTimeval_clamp,
    _PyTime_FromMillisecondsObject,
    _PyTime_FromSecondsObject,
    PyTuple_New,
    PyUnicode_FromString
}
import from jaclang.runtime.python.capi {
    boundary_failure,
    object_error,
    object_tuple,
    text_value,
    type_name
}
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat }
import from jaclang.runtime.python.bindings.converters {
    ClassToken,
    borrowed_false,
    borrowed_none,
    borrowed_true
}
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    builtin_function,
    jacpy_binding_module_native_get,
    jacpy_binding_module_native_present,
    jacpy_binding_state_get,
    visit_reference
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_matches,
    jacpy_binding_owner
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.members { MemberField }
import from jaclang.runtime.python.modules.time_records { timespec, timeval }
import from jaclang.runtime.python.modules.select_platform {
    EPOLL_DATA_OFFSET,
    EPOLL_EVENT_SIZE,
    KEVENT_MEMBERS,
    KEVENT_SIZE,
    epoll_create1,
    epoll_ctl,
    epoll_wait,
    kevent,
    kevent_record,
    kqueue,
    poll_fds,
    pollfd,
    select
}
import from jaclang.runtime.python.modules.select_constants {
    EPOLL_CLOEXEC,
    EPOLL_CTL_ADD,
    EPOLL_CTL_DEL,
    EPOLL_CTL_MOD,
    EPOLLIN,
    EPOLLOUT,
    EPOLLPRI,
    FD_SETSIZE,
    KQ_EV_ADD,
    KQ_FILTER_READ,
    POLLIN,
    POLLNVAL,
    POLLOUT,
    POLLPRI
}
import from jaclang.runtime.python.modules.errno_constants { EINTR, EINVAL, ENOENT }
import from c { def close(fd: i32) -> i32;  def pipe(fds: ptr[i32]) -> i32;  }

glob:priv INT_MAX: int = 2147483647,
     INT_MIN: int = -2147483648,
     SSIZE_MAX: int = 0x7FFFFFFFFFFFFFFF,
     ROUND_CEILING: i32 = 1,
     ROUND_TIMEOUT: i32 = 3,
     POLLFD_SIZE: int = 8,
     TIMESPEC_SIZE: int = 16,
     # Py_ASNATIVEBYTES_NATIVE_ENDIAN | UNSIGNED_BUFFER | REJECT_NEGATIVE | ALLOW_INDEX
     IDENT_BYTES_FLAGS: i32 = i32(3 | 4 | 8 | 16),
     # Module state slots of the object types.
     POLL_TYPE: int = 0,
     EPOLL_TYPE: int = 1,
     KEVENT_TYPE: int = 2,
     KQUEUE_TYPE: int = 3;

# Handles the binding fills in: the module definition and each type's.
obj DefinitionHandle {
    has handle: ptr = ptr();
}

glob module_definition = DefinitionHandle(),
     poll_token = ClassToken(),
     epoll_token = ClassToken(),
     kevent_token = ClassToken(),
     kqueue_token = ClassToken();

# _selectstate: the interned "close" and the open kqueue objects, borrowed,
# that a fork invalidates.
obj SelectState(NativeState) {
    has close: ptr[PyObject] = NULL,
        open_queues: list[ptr[PyObject]] = [],
        tracking_initialized: bool = False;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return visit_reference(self.close, visitor, context);
    }

    def clear {
        previous = self.close;
        self.close = NULL;
        jacpy_release(previous);
    }

    def drop {
        self.clear();
    }
}

def select_state(module: ptr[PyObject]) -> (SelectState | None) {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, SelectState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "select module state is unavailable");
    return None;
}

# The select module an object's type belongs to, borrowed.
def:priv module_of(instance: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(Py_TYPE(instance), module_definition.handle);
}

def:priv os_error -> ptr[PyObject] {
    PyErr_SetFromErrno(PyExc_OSError);
    return NULL;
}

def:priv errno_error(code: i64) -> ptr[PyObject] {
    jacpy_set_errno(code);
    return os_error();
}

def:priv type_error_matches -> bool {
    return PyErr_ExceptionMatches(PyExc_TypeError) != 0;
}

# ---------------------------------------------------------------- select()

# The objects of one select() argument with their descriptors: seq2set()'s
# pylist, which owns each object until set2list() hands it on.
obj DescriptorList {
    has objects: list[ptr[PyObject]] = [],
        fds: list[int] = [];

    def reap {
        held = self.objects;
        self.objects = [];
        self.fds = [];
        for value in held {
            jacpy_release(value);
        }
    }

    def drop {
        self.reap();
    }
}

# seq2set(): mark each descriptor of `seq` in the fd_set at `bits`; the
# highest descriptor plus one, or -1 with the exception set.
def:priv seq2set(seq: ptr[PyObject], bits: ptr[u8], entries: DescriptorList) -> int {
    fast = PySequence_Fast(seq, "arguments 1-3 must be sequences");
    if not fast {
        return -1;
    }
    set_bits = bits.view(int(FD_SETSIZE) // 8);
    highest = -1;
    # The size is read on every step: fileno() may shrink a list argument.
    i = 0;
    while i < int(jacpy_fast_size(fast)) {
        o = jacpy_fast_item(fast, i64(i));
        i += 1;
        v = int(PyObject_AsFileDescriptor(o));
        if v == -1 {
            jacpy_release(o);
            jacpy_release(fast);
            return -1;
        }
        if v < 0 or v >= FD_SETSIZE {
            jacpy_release(o);
            jacpy_release(fast);
            object_error(PyExc_ValueError, "filedescriptor out of range in select()");
            return -1;
        }
        if v > highest {
            highest = v;
        }
        set_bits[v >> 3] = set_bits[v >> 3] | u8(1 << (v & 7));
        if len(entries.objects) >= FD_SETSIZE {
            jacpy_release(o);
            jacpy_release(fast);
            object_error(PyExc_ValueError, "too many file descriptors in select()");
            return -1;
        }
        entries.objects.append(o);
        entries.fds.append(v);
    }
    jacpy_release(fast);
    return highest + 1;
}

# set2list(): the objects whose descriptors select() left set, taking them
# over from `entries`.
def:priv set2list(bits: ptr[u8], entries: DescriptorList) -> ptr[PyObject] {
    set_bits = bits.view(int(FD_SETSIZE) // 8);
    ready: list[int] = [];
    for j in range(len(entries.fds)) {
        fd = entries.fds[j];
        if (int(set_bits[fd >> 3]) >> (fd & 7)) & 1 != 0 {
            ready.append(j);
        }
    }
    result = PyList_New(i64(len(ready)));
    if not result {
        return NULL;
    }
    for i in range(len(ready)) {
        o = entries.objects[ready[i]];
        entries.objects[ready[i]] = NULL;
        if PyList_SetItem(result, i64(i), o) < 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}

def select_select_impl(
    module: ptr[PyObject],
    rlist: ptr[PyObject],
    wlist: ptr[PyObject],
    xlist: ptr[PyObject],
    timeout_obj: ptr[PyObject]
) -> ptr[PyObject] {
    timeout: i64 = 0;
    tv = timeval();
    has_timeout = timeout_obj != Py_None;
    if has_timeout {
        if _PyTime_FromSecondsObject(&mut timeout, timeout_obj, ROUND_TIMEOUT) < 0 {
            if type_error_matches() {
                object_error(PyExc_TypeError, "timeout must be a float or None");
            }
            return NULL;
        }
        if _PyTime_AsTimeval(timeout, &mut tv, ROUND_TIMEOUT) == -1 {
            return NULL;
        }
        if tv.tv_sec < 0 {
            object_error(PyExc_ValueError, "timeout must be non-negative");
            return NULL;
        }
    }
    set_size = int(FD_SETSIZE) // 8;
    # Three fd_sets followed by the struct timeval select() may update.
    memory = PyMem_Calloc(1, u64(3 * set_size + 16));
    if not memory {
        return PyErr_NoMemory();
    }
    input = ptr[u8](memory);
    output = input + set_size;
    exceptional = output + set_size;
    timeout_record = ptr[timeval](exceptional + set_size);
    readers = DescriptorList();
    writers = DescriptorList();
    errors = DescriptorList();
    result = NULL;
    imax = seq2set(rlist, input, readers);
    omax = seq2set(wlist, output, writers) if imax >= 0 else -1;
    emax = seq2set(xlist, exceptional, errors) if omax >= 0 else -1;
    if emax >= 0 {
        highest = max(imax, max(omax, emax));
        deadline: i64 = 0;
        if has_timeout {
            timeout_record.view(1)[0] = tv;
            deadline = _PyDeadline_Init(timeout);
        }
        n: i32 = 0;
        interrupted = False;
        while True {
            thread = PyEval_SaveThread();
            jacpy_set_errno(0);
            n = select(
                i32(highest),
                ptr(input) if imax else ptr(),
                ptr(output) if omax else ptr(),
                ptr(exceptional) if emax else ptr(),
                ptr(timeout_record) if has_timeout else ptr()
            );
            PyEval_RestoreThread(thread);
            if jacpy_errno() != EINTR {
                break;
            }
            if PyErr_CheckSignals() != 0 {
                interrupted = True;
                break;
            }
            if has_timeout {
                timeout = _PyDeadline_Get(deadline);
                if timeout < 0 {
                    # bpo-35310: the sets are unmodified; clear them explicitly.
                    for k in range(3 * set_size) {
                        input.view(3 * set_size)[k] = u8(0);
                    }
                    n = 0;
                    break;
                }
                _PyTime_AsTimeval_clamp(timeout, &mut tv, ROUND_CEILING);
                timeout_record.view(1)[0] = tv;
            }
        }
        if interrupted {
            result = NULL;
        } elif n < 0 {
            os_error();
        } else {
            ready_r = set2list(input, readers);
            ready_w = set2list(output, writers);
            ready_x = set2list(exceptional, errors);
            if not PyErr_Occurred() {
                result = object_tuple([ready_r, ready_w, ready_x]);
            }
            jacpy_release(ready_r);
            jacpy_release(ready_w);
            jacpy_release(ready_x);
        }
    }
    readers.reap();
    writers.reap();
    errors.reap();
    PyMem_Free(memory);
    return result;
}

# ------------------------------------------------------------------ poll()

# pollObject: registered descriptors in a dict, mirrored into an array of
# struct pollfd whenever the dict changed since the last poll().
obj PollState(NativeState) {
    has dict: ptr[PyObject] = NULL,
        ufd_uptodate: bool = False,
        ufd_len: int = 0,
        ufds: ptr[pollfd] = ptr[pollfd](),
        poll_running: bool = False;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        PyMem_Free(ptr(self.ufds));
        jacpy_release(self.dict);
    }
}

def:priv poll_of(instance: ptr[PyObject]) -> (PollState | None) {
    if jacpy_binding_native_present(instance, poll_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, poll_token.handle);
        if isinstance(state, PollState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "poll state is unavailable");
    return None;
}

# update_ufd_array(): rebuild the pollfd array from the dict.
def:priv update_ufd_array(state: PollState) -> bool {
    count = int(jacpy_dict_size(state.dict));
    grown = PyMem_Realloc(ptr(state.ufds), u64(count * POLLFD_SIZE));
    if not grown {
        PyErr_NoMemory();
        return False;
    }
    state.ufds = ptr[pollfd](grown);
    state.ufd_len = count;
    position: i64 = 0;
    key = NULL;
    value = NULL;
    i = 0;
    while PyDict_Next(state.dict, &mut position, &mut key, &mut value) != 0 {
        record = (state.ufds + i).view(1);
        record[0].fd = i32.wrap(PyLong_AsLong(key));
        record[0].events = i16.wrap(PyLong_AsLong(value));
        i += 1;
    }
    state.ufd_uptodate = True;
    return True;
}

def select_poll_register_impl(
    receiver: ptr[PyObject], fd: i32, eventmask: u16
) -> ptr[PyObject] {
    state = poll_of(receiver);
    if state is None {
        return NULL;
    }
    key = PyLong_FromLong(i64(fd));
    if not key {
        return NULL;
    }
    value = PyLong_FromLong(i64(eventmask));
    if not value {
        jacpy_release(key);
        return NULL;
    }
    err = PyDict_SetItem(state.dict, key, value);
    jacpy_release(key);
    jacpy_release(value);
    if err < 0 {
        return NULL;
    }
    state.ufd_uptodate = False;
    return Py_NewRef(borrowed_none());
}

def select_poll_modify_impl(
    receiver: ptr[PyObject], fd: i32, eventmask: u16
) -> ptr[PyObject] {
    state = poll_of(receiver);
    if state is None {
        return NULL;
    }
    key = PyLong_FromLong(i64(fd));
    if not key {
        return NULL;
    }
    err = PyDict_Contains(state.dict, key);
    if err < 0 {
        jacpy_release(key);
        return NULL;
    }
    if err == 0 {
        jacpy_release(key);
        return errno_error(ENOENT);
    }
    value = PyLong_FromLong(i64(eventmask));
    if not value {
        jacpy_release(key);
        return NULL;
    }
    err = PyDict_SetItem(state.dict, key, value);
    jacpy_release(key);
    jacpy_release(value);
    if err < 0 {
        return NULL;
    }
    state.ufd_uptodate = False;
    return Py_NewRef(borrowed_none());
}

def select_poll_unregister_impl(receiver: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    state = poll_of(receiver);
    if state is None {
        return NULL;
    }
    key = PyLong_FromLong(i64(fd));
    if not key {
        return NULL;
    }
    # An unregistered descriptor raises PyDict_DelItem's KeyError.
    status = PyDict_DelItem(state.dict, key);
    jacpy_release(key);
    if status == -1 {
        return NULL;
    }
    state.ufd_uptodate = False;
    return Py_NewRef(borrowed_none());
}

# A timeout in milliseconds for poll() or epoll_wait(), or None.
def:priv milliseconds_in_range(ms: i64) -> bool {
    if ms < INT_MIN or ms > INT_MAX {
        object_error(PyExc_OverflowError, "timeout is too large");
        return False;
    }
    return True;
}

def select_poll_poll_impl(
    receiver: ptr[PyObject], timeout_obj: ptr[PyObject]
) -> ptr[PyObject] {
    state = poll_of(receiver);
    if state is None {
        return NULL;
    }
    timeout: i64 = -1;
    ms: i64 = -1;
    deadline: i64 = 0;
    if timeout_obj != Py_None {
        if _PyTime_FromMillisecondsObject(&mut timeout, timeout_obj, ROUND_TIMEOUT)
            < 0 {
            if type_error_matches() {
                object_error(PyExc_TypeError, "timeout must be an integer or None");
            }
            return NULL;
        }
        ms = _PyTime_AsMilliseconds(timeout, ROUND_TIMEOUT);
        if not milliseconds_in_range(ms) {
            return NULL;
        }
        if timeout >= 0 {
            deadline = _PyDeadline_Init(timeout);
        }
    }
    # A negative timeout must be exactly -1 (no target defines INFTIM).
    if ms < 0 {
        ms = -1;
    }
    if state.poll_running {
        object_error(PyExc_RuntimeError, "concurrent poll() invocation");
        return NULL;
    }
    if not state.ufd_uptodate and not update_ufd_array(state) {
        return NULL;
    }
    state.poll_running = True;
    poll_result: i32 = 0;
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        jacpy_set_errno(0);
        poll_result = poll_fds(state.ufds, state.ufd_len, i32(ms));
        PyEval_RestoreThread(thread);
        if jacpy_errno() != EINTR {
            break;
        }
        if PyErr_CheckSignals() != 0 {
            async_err = True;
            break;
        }
        if timeout >= 0 {
            timeout = _PyDeadline_Get(deadline);
            if timeout < 0 {
                poll_result = 0;
                break;
            }
            ms = _PyTime_AsMilliseconds(timeout, ROUND_CEILING);
        }
    }
    state.poll_running = False;
    if poll_result < 0 {
        if not async_err {
            os_error();
        }
        return NULL;
    }
    result_list = PyList_New(i64(poll_result));
    if not result_list {
        return NULL;
    }
    i = 0;
    for j in range(int(poll_result)) {
        while (state.ufds + i).view(1)[0].revents == 0 {
            i += 1;
        }
        record = (state.ufds + i).view(1)[0];
        # The & 0xffff keeps a 16-bit POLLNVAL of 0x8000 positive.
        value = pair_of(
            PyLong_FromLong(i64(record.fd)),
            PyLong_FromLong(i64(record.revents) & 0xFFFF)
        );
        if not value {
            jacpy_release(result_list);
            return NULL;
        }
        PyList_SetItem(result_list, i64(j), value);
        i += 1;
    }
    return result_list;
}

# A 2-tuple taking over two new references; NULL if either is NULL.
def:priv pair_of(first: ptr[PyObject], second: ptr[PyObject]) -> ptr[PyObject] {
    if not first or not second {
        jacpy_release(first);
        jacpy_release(second);
        return NULL;
    }
    result = PyTuple_New(2);
    if not result {
        jacpy_release(first);
        jacpy_release(second);
        return NULL;
    }
    jacpy_tuple_set_owned(result, 0, first);
    jacpy_tuple_set_owned(result, 1, second);
    return result;
}

# newPollObject()
def select_poll_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(jacpy_binding_state_get(module, POLL_TYPE));
    if not instance {
        return NULL;
    }
    state = PollState(dict=PyDict_New());
    if not state.dict
        or jacpy_binding_native_set(instance, poll_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

# select_have_broken_poll(): whether poll() fails, rather than reporting
# POLLNVAL, for a descriptor that is not open.
def have_broken_poll -> bool {
    memory = PyMem_Calloc(1, u64(2 * 4 + POLLFD_SIZE));
    if not memory {
        return True;
    }
    filedes = ptr[i32](memory);
    probe = ptr[pollfd](ptr[u8](memory) + 8);
    broken = True;
    if pipe(filedes) == 0 {
        descriptors = filedes.view(2);
        probe.view(1)[0] = pollfd(
            fd=descriptors[0], events=i16(POLLIN | POLLPRI | POLLOUT), revents=i16(0)
        );
        close(descriptors[0]);
        close(descriptors[1]);
        poll_test = poll_fds(probe, 1, i32(0));
        broken = poll_test < 0
            or (poll_test == 0 and probe.view(1)[0].revents != i16(POLLNVAL));
    }
    PyMem_Free(memory);
    return broken;
}

# ----------------------------------------------------------------- devpoll

def:priv devpoll_unavailable -> ptr[PyObject] {
    object_error(PyExc_OSError, "/dev/poll is not available on this platform");
    return NULL;
}

def select_devpoll_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return devpoll_unavailable();
}

def select_devpoll_register_impl(
    receiver: ptr[PyObject], fd: i32, eventmask: u16
) -> ptr[PyObject] {
    return devpoll_unavailable();
}

def select_devpoll_modify_impl(
    receiver: ptr[PyObject], fd: i32, eventmask: u16
) -> ptr[PyObject] {
    return devpoll_unavailable();
}

def select_devpoll_unregister_impl(receiver: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    return devpoll_unavailable();
}

def select_devpoll_poll_impl(
    receiver: ptr[PyObject], timeout_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return devpoll_unavailable();
}

def select_devpoll_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return devpoll_unavailable();
}

def select_devpoll_fileno_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return devpoll_unavailable();
}

# ------------------------------------------------------------------- epoll

obj EpollState(NativeState) {
    has epfd: i32 = -1;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
}

def epoll_of(instance: ptr[PyObject]) -> (EpollState | None) {
    if jacpy_binding_native_present(instance, epoll_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, epoll_token.handle);
        if isinstance(state, EpollState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "epoll state is unavailable");
    return None;
}

def:priv epoll_closed -> ptr[PyObject] {
    object_error(PyExc_ValueError, "I/O operation on closed epoll object");
    return NULL;
}

# pyepoll_internal_close(): the errno of a failed close(), else 0.
def epoll_internal_close(state: EpollState) -> i64 {
    save_errno: i64 = 0;
    if state.epfd >= 0 {
        epfd = state.epfd;
        state.epfd = i32(-1);
        thread = PyEval_SaveThread();
        if close(epfd) < 0 {
            save_errno = jacpy_errno();
        }
        PyEval_RestoreThread(thread);
    }
    return save_errno;
}

# newPyEpoll_Object(): a new epoll descriptor when `fd` is -1.
def:priv new_epoll(type: ptr[PyObject], sizehint: int, fd: i32) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    state = EpollState();
    if fd == -1 {
        thread = PyEval_SaveThread();
        state.epfd = epoll_create1(i32(EPOLL_CLOEXEC));
        PyEval_RestoreThread(thread);
    } else {
        state.epfd = fd;
    }
    if state.epfd < 0 {
        os_error();
        jacpy_release(instance);
        return NULL;
    }
    if jacpy_binding_native_set(instance, epoll_token.handle, state) < 0 {
        epoll_internal_close(state);
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def select_epoll_impl(type: ptr[PyObject], sizehint: i32, flags: i32) -> ptr[PyObject] {
    hint = int(sizehint);
    if hint == -1 {
        hint = int(FD_SETSIZE) - 1;
    } elif hint <= 0 {
        object_error(PyExc_ValueError, "negative sizehint");
        return NULL;
    }
    if flags != 0 and i64(flags) != EPOLL_CLOEXEC {
        object_error(PyExc_OSError, "invalid flags");
        return NULL;
    }
    return new_epoll(type, hint, i32(-1));
}

def select_epoll_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = epoll_of(receiver);
    if state is None {
        return NULL;
    }
    # CPython tests the saved errno for being negative, which it never is,
    # so a failed close() is not reported.
    save_errno = epoll_internal_close(state);
    jacpy_set_errno(save_errno);
    if save_errno < 0 {
        return os_error();
    }
    return Py_NewRef(borrowed_none());
}

def epoll_closed_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = epoll_of(instance);
    if state is None {
        return NULL;
    }
    return Py_NewRef(borrowed_true() if state.epfd < 0 else borrowed_false());
}

def select_epoll_fileno_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = epoll_of(receiver);
    if state is None {
        return NULL;
    }
    if state.epfd < 0 {
        return epoll_closed();
    }
    return PyLong_FromLong(i64(state.epfd));
}

def select_epoll_fromfd_impl(type: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    return new_epoll(type, int(FD_SETSIZE) - 1, fd);
}

# pyepoll_internal_ctl(): epoll_ctl() with a struct epoll_event whose data
# member holds the descriptor.
def:priv epoll_internal_ctl(epfd: i32, op: i64, fd: i32, events: u32) -> ptr[PyObject] {
    if epfd < 0 {
        return epoll_closed();
    }
    event = PyMem_Calloc(1, u64(EPOLL_EVENT_SIZE));
    if not event {
        return PyErr_NoMemory();
    }
    result: i32 = -1;
    if op == EPOLL_CTL_ADD or op == EPOLL_CTL_MOD {
        ptr[u32](event).view(1)[0] = events;
        ptr[i32](ptr[u8](event) + EPOLL_DATA_OFFSET).view(1)[0] = fd;
        thread = PyEval_SaveThread();
        result = epoll_ctl(epfd, i32(op), fd, event);
        PyEval_RestoreThread(thread);
    } elif op == EPOLL_CTL_DEL {
        # Kernels before 2.6.9 required a non-NULL event for EPOLL_CTL_DEL.
        thread = PyEval_SaveThread();
        result = epoll_ctl(epfd, i32(op), fd, event);
        PyEval_RestoreThread(thread);
    } else {
        jacpy_set_errno(EINVAL);
    }
    PyMem_Free(event);
    if result < 0 {
        return os_error();
    }
    return Py_NewRef(borrowed_none());
}

def select_epoll_register_impl(
    receiver: ptr[PyObject], fd: i32, eventmask: u32
) -> ptr[PyObject] {
    state = epoll_of(receiver);
    if state is None {
        return NULL;
    }
    return epoll_internal_ctl(state.epfd, EPOLL_CTL_ADD, fd, eventmask);
}

def select_epoll_modify_impl(
    receiver: ptr[PyObject], fd: i32, eventmask: u32
) -> ptr[PyObject] {
    state = epoll_of(receiver);
    if state is None {
        return NULL;
    }
    return epoll_internal_ctl(state.epfd, EPOLL_CTL_MOD, fd, eventmask);
}

def select_epoll_unregister_impl(receiver: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    state = epoll_of(receiver);
    if state is None {
        return NULL;
    }
    return epoll_internal_ctl(state.epfd, EPOLL_CTL_DEL, fd, u32(0));
}

def select_epoll_poll_impl(
    receiver: ptr[PyObject], timeout_obj: ptr[PyObject], maxevents: i32
) -> ptr[PyObject] {
    state = epoll_of(receiver);
    if state is None {
        return NULL;
    }
    if state.epfd < 0 {
        return epoll_closed();
    }
    timeout: i64 = -1;
    ms: i64 = -1;
    deadline: i64 = 0;
    if timeout_obj != Py_None {
        # epoll_wait() has millisecond resolution; round up so the wait is
        # at least the timeout.
        if _PyTime_FromSecondsObject(&mut timeout, timeout_obj, ROUND_TIMEOUT) < 0 {
            if type_error_matches() {
                object_error(PyExc_TypeError, "timeout must be an integer or None");
            }
            return NULL;
        }
        ms = _PyTime_AsMilliseconds(timeout, ROUND_CEILING);
        if not milliseconds_in_range(ms) {
            return NULL;
        }
        if ms < 0 {
            ms = -1;
        }
        if timeout >= 0 {
            deadline = _PyDeadline_Init(timeout);
        }
    }
    count = int(maxevents);
    if count == -1 {
        count = int(FD_SETSIZE) - 1;
    } elif count < 1 {
        object_error(
            PyExc_ValueError, f"maxevents must be greater than 0, got {maxevents}"
        );
        return NULL;
    }
    if count > SSIZE_MAX // EPOLL_EVENT_SIZE {
        return PyErr_NoMemory();
    }
    events = PyMem_Malloc(u64(count * EPOLL_EVENT_SIZE));
    if not events {
        return PyErr_NoMemory();
    }
    nfds: i32 = 0;
    while True {
        thread = PyEval_SaveThread();
        jacpy_set_errno(0);
        nfds = epoll_wait(state.epfd, events, i32(count), i32(ms));
        PyEval_RestoreThread(thread);
        if jacpy_errno() != EINTR {
            break;
        }
        if PyErr_CheckSignals() != 0 {
            PyMem_Free(events);
            return NULL;
        }
        if timeout >= 0 {
            timeout = _PyDeadline_Get(deadline);
            if timeout < 0 {
                nfds = 0;
                break;
            }
            ms = _PyTime_AsMilliseconds(timeout, ROUND_CEILING);
        }
    }
    if nfds < 0 {
        PyMem_Free(events);
        return os_error();
    }
    elist = PyList_New(i64(nfds));
    if elist {
        for i in range(int(nfds)) {
            record = ptr[u8](events) + i * EPOLL_EVENT_SIZE;
            etuple = pair_of(
                PyLong_FromLong(i64(ptr[i32](record + EPOLL_DATA_OFFSET).view(1)[0])),
                PyLong_FromUnsignedLong(u64(ptr[u32](record).view(1)[0]))
            );
            if not etuple {
                jacpy_release(elist);
                elist = NULL;
                break;
            }
            PyList_SetItem(elist, i64(i), etuple);
        }
    }
    PyMem_Free(events);
    return elist;
}

def select_epoll___enter___impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = epoll_of(receiver);
    if state is None {
        return NULL;
    }
    if state.epfd < 0 {
        return epoll_closed();
    }
    return Py_NewRef(receiver);
}

def select_epoll___exit___impl(
    receiver: ptr[PyObject],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_tb: ptr[PyObject]
) -> ptr[PyObject] {
    module_state = select_state(module_of(receiver));
    if module_state is None {
        return NULL;
    }
    method = PyObject_GetAttr(receiver, module_state.close);
    if not method {
        return NULL;
    }
    result = PyObject_CallNoArgs(method);
    jacpy_release(method);
    return result;
}

# ------------------------------------------------------------------ kevent

# kqueue_event_Object: its struct kevent lives in memory the state owns, so
# the attributes read and write it with structmember's conversions.
obj KeventState(NativeState) {
    has record: ptr[kevent_record] = ptr[kevent_record]();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        PyMem_Free(ptr(self.record));
    }
}

def kevent_of(instance: ptr[PyObject]) -> (KeventState | None) {
    if jacpy_binding_native_present(instance, kevent_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, kevent_token.handle);
        if isinstance(state, KeventState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "kevent state is unavailable");
    return None;
}

# A kevent object holding a copy of `event`, or a zeroed one.
def new_kevent(type: ptr[PyObject], event: kevent_record | None) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    memory = PyMem_Calloc(1, u64(KEVENT_SIZE));
    if not memory {
        jacpy_release(instance);
        return PyErr_NoMemory();
    }
    state = KeventState(record=ptr[kevent_record](memory));
    if event is not None {
        state.record.view(1)[0] = event;
    }
    if jacpy_binding_native_set(instance, kevent_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

# tp_new: PyType_GenericNew's zeroed event.
def kqueue_event_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return new_kevent(type, None);
}

# kqueue_event_init(): kevent(ident, filter=KQ_FILTER_READ, flags=KQ_EV_ADD,
# fflags=0, data=0, udata=0).
def kqueue_event_init(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    state = kevent_of(instance);
    if state is None {
        return i32(-1);
    }
    event = state.record.view(1);
    event[0] = kevent_record(
        ident=u64(0),
        filter=i16(KQ_FILTER_READ),
        flags=u16(KQ_EV_ADD),
        fflags=u32(0),
        data=i64(0),
        udata=u64(0)
    );
    try {
        values = ArgumentFormat(name="kevent").parse_keywords(
            args,
            kwargs,
            "O|hHILK",
            ["ident", "filter", "flags", "fflags", "data", "udata"]
        );
    } except boundary_failure {
        return i32(-1);
    }
    if values[1].given {
        event[0].filter = i16(values[1].signed);
    }
    if values[2].given {
        event[0].flags = u16(values[2].unsigned);
    }
    if values[3].given {
        event[0].fflags = u32(values[3].unsigned);
    }
    if values[4].given {
        event[0].data = values[4].signed;
    }
    if values[5].given {
        event[0].udata = values[5].unsigned;
    }
    pfd = values[0].object;
    if PyIndex_Check(pfd) != 0 {
        written = PyLong_AsNativeBytes(pfd, ptr(state.record), 8, IDENT_BYTES_FLAGS);
        if written < 0 {
            return i32(-1);
        }
        if written > 8 {
            object_error(
                PyExc_OverflowError, "Python int too large for C kqueue event identifier"
            );
            return i32(-1);
        }
    } else {
        event[0].ident = u64.wrap(i64(PyObject_AsFileDescriptor(pfd)));
        if PyErr_Occurred() {
            return i32(-1);
        }
    }
    return i32(0);
}

def:priv lowercase_hex(value: u64) -> str {
    digits = "0123456789abcdef";
    if value == u64(0) {
        return "0";
    }
    text = "";
    remaining = value;
    while remaining != u64(0) {
        text = digits[int(remaining & u64(15))] + text;
        remaining = remaining >> u64(4);
    }
    return text;
}

def kqueue_event_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = kevent_of(instance);
    if state is None {
        return NULL;
    }
    e = state.record.view(1)[0];
    return PyUnicode_FromString(
        f"<select.kevent ident={e.ident} filter={e.filter} flags=0x{lowercase_hex(
            u64(e.flags)
        )} fflags=0x{lowercase_hex(u64(e.fflags))} data=0x{lowercase_hex(
            u64.wrap(e.data)
        )} udata=0x{lowercase_hex(e.udata)}>"
    );
}

# kqueue_event_richcompare(): field by field, udata as a signed intptr_t.
def kqueue_event_richcompare(
    lhs: ptr[PyObject], rhs: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if jacpy_binding_matches(rhs, kevent_token.handle) == 0 {
        return Py_NotImplemented;
    }
    left_state = kevent_of(lhs);
    right_state = kevent_of(rhs);
    if left_state is None or right_state is None {
        return NULL;
    }
    s = left_state.record.view(1)[0];
    o = right_state.record.view(1)[0];
    pairs = [
        (int(s.ident > o.ident) - int(s.ident < o.ident)),
        (int(s.filter > o.filter) - int(s.filter < o.filter)),
        (int(s.flags > o.flags) - int(s.flags < o.flags)),
        (int(s.fflags > o.fflags) - int(s.fflags < o.fflags)),
        (int(s.data > o.data) - int(s.data < o.data)),
        (
            int(i64.wrap(s.udata) > i64.wrap(o.udata))
            - int(i64.wrap(s.udata) < i64.wrap(o.udata))
        )
    ];
    result = 0;
    for difference in pairs {
        if difference != 0 {
            result = difference;
            break;
        }
    }
    outcome = [
        result < 0,
        result <= 0,
        result == 0,
        result != 0,
        result > 0,
        result >= 0
    ][int(op)];
    return Py_NewRef(borrowed_true() if outcome else borrowed_false());
}

# The kevent attribute `context` indexes KEVENT_MEMBERS.
def:priv kevent_field(context: u64) -> MemberField {
    return KEVENT_MEMBERS[int(context)];
}

def kevent_member_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = kevent_of(instance);
    if state is None {
        return NULL;
    }
    return kevent_field(context).read(ptr(state.record));
}

def kevent_member_set(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    state = kevent_of(instance);
    if state is None {
        return i32(-1);
    }
    return kevent_field(context).write(ptr(state.record), value);
}

# ------------------------------------------------------------------ kqueue

obj KqueueState(NativeState) {
    has kqfd: i32 = -1;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
}

def kqueue_of(instance: ptr[PyObject]) -> (KqueueState | None) {
    if jacpy_binding_native_present(instance, kqueue_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, kqueue_token.handle);
        if isinstance(state, KqueueState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "kqueue state is unavailable");
    return None;
}

def:priv kqueue_closed -> ptr[PyObject] {
    object_error(PyExc_ValueError, "I/O operation on closed kqueue object");
    return NULL;
}

# kqueue_tracking_after_fork(): a forked child inherits no kqueue, so every
# open kqueue object forgets its descriptor.
def kqueue_tracking_after_fork(
    module: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    module_state = select_state(module);
    if module_state is None {
        return NULL;
    }
    queues = module_state.open_queues;
    module_state.open_queues = [];
    for queue in queues {
        state = kqueue_of(queue);
        if state is not None {
            state.kqfd = i32(-1);
        }
    }
    return Py_NewRef(borrowed_none());
}

# kqueue_tracking_init(): register the after-fork hook once per module; a
# failure is reported as a RuntimeWarning.
def:priv kqueue_tracking_init(module: ptr[PyObject], module_state: SelectState) {
    register_at_fork = PyImport_ImportModuleAttrString("posix", "register_at_fork");
    if register_at_fork {
        callback = builtin_function(
            MethodDefinition(
                "kqueue_tracking_after_fork",
                MethodCallbacks(positional=kqueue_tracking_after_fork),
                "Invalidate open select.kqueue objects after fork.",
                flags=4
            ),
            module
        );
        if callback {
            arguments = PyTuple_New(0);
            keywords = PyDict_New();
            if arguments and keywords {
                name = PyUnicode_FromString("after_in_child");
                if name {
                    if PyDict_SetItem(keywords, name, callback) == 0 {
                        jacpy_release(
                            PyObject_Call(register_at_fork, arguments, keywords)
                        );
                    }
                    jacpy_release(name);
                }
            }
            jacpy_release(arguments);
            jacpy_release(keywords);
            jacpy_release(callback);
        }
        jacpy_release(register_at_fork);
    }
    if PyErr_Occurred() {
        error = PyErr_GetRaisedException();
        type_text = PyObject_Str(Py_TYPE(error));
        error_text = PyObject_Str(error);
        if type_text and error_text {
            PyErr_WarnEx(
                PyExc_RuntimeWarning,
                f"An exception of type {text_value(
                    type_text
                )} was raised while registering an after-fork handler for select.kqueue objects: {text_value(
                    error_text
                )}",
                1
            );
        }
        jacpy_release(type_text);
        jacpy_release(error_text);
        jacpy_release(error);
    }
    module_state.tracking_initialized = True;
}

def:priv kqueue_tracking_remove(instance: ptr[PyObject]) {
    module_state = select_state(module_of(instance));
    if module_state is None {
        return;
    }
    for i in range(len(module_state.open_queues)) {
        if module_state.open_queues[i] == instance {
            module_state.open_queues.pop(i);
            return;
        }
    }
}

# kqueue_queue_internal_close(): the errno of a failed close(), else 0.
def kqueue_internal_close(instance: ptr[PyObject], state: KqueueState) -> i64 {
    save_errno: i64 = 0;
    if state.kqfd >= 0 {
        kqfd = state.kqfd;
        state.kqfd = i32(-1);
        kqueue_tracking_remove(instance);
        thread = PyEval_SaveThread();
        if close(kqfd) < 0 {
            save_errno = jacpy_errno();
        }
        PyEval_RestoreThread(thread);
    }
    return save_errno;
}

# kqueue_queue_finalize(): close the descriptor, keeping any pending exception.
def kqueue_finalize(instance: ptr[PyObject]) {
    if jacpy_binding_native_present(instance, kqueue_token.handle) == 0 {
        return;
    }
    error = PyErr_GetRaisedException();
    state = kqueue_of(instance);
    if state is not None {
        kqueue_internal_close(instance, state);
    }
    PyErr_SetRaisedException(error);
}

# newKqueue_Object(): a new kqueue when `fd` is -1, tracked until closed.
def:priv new_kqueue(type: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    state = KqueueState();
    if fd == -1 {
        thread = PyEval_SaveThread();
        state.kqfd = kqueue();
        PyEval_RestoreThread(thread);
    } else {
        state.kqfd = fd;
    }
    if state.kqfd < 0 {
        os_error();
        jacpy_release(instance);
        return NULL;
    }
    if jacpy_binding_native_set(instance, kqueue_token.handle, state) < 0 {
        close(state.kqfd);
        jacpy_release(instance);
        return NULL;
    }
    if fd == -1 {
        atomic: i32 = 0;
        if _Py_set_inheritable(state.kqfd, 0, &mut atomic) < 0 {
            jacpy_release(instance);
            return NULL;
        }
    }
    module_state = select_state(jacpy_binding_owner(type, module_definition.handle));
    if module_state is None {
        jacpy_release(instance);
        return NULL;
    }
    if not module_state.tracking_initialized {
        kqueue_tracking_init(module_of(instance), module_state);
    }
    module_state.open_queues.append(instance);
    return instance;
}

def select_kqueue_impl(type: ptr[PyObject]) -> ptr[PyObject] {
    return new_kqueue(type, i32(-1));
}

def select_kqueue_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = kqueue_of(receiver);
    if state is None {
        return NULL;
    }
    # As for epoll, CPython tests the saved errno for being negative.
    save_errno = kqueue_internal_close(receiver, state);
    jacpy_set_errno(save_errno);
    if save_errno < 0 {
        return os_error();
    }
    return Py_NewRef(borrowed_none());
}

def kqueue_closed_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = kqueue_of(instance);
    if state is None {
        return NULL;
    }
    return Py_NewRef(borrowed_true() if state.kqfd < 0 else borrowed_false());
}

def select_kqueue_fileno_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = kqueue_of(receiver);
    if state is None {
        return NULL;
    }
    if state.kqfd < 0 {
        return kqueue_closed();
    }
    return PyLong_FromLong(i64(state.kqfd));
}

def select_kqueue_fromfd_impl(type: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    return new_kqueue(type, fd);
}

def select_kqueue_control_impl(
    receiver: ptr[PyObject],
    changelist: ptr[PyObject],
    maxevents: i32,
    otimeout: ptr[PyObject]
) -> ptr[PyObject] {
    state = kqueue_of(receiver);
    if state is None {
        return NULL;
    }
    if state.kqfd < 0 {
        return kqueue_closed();
    }
    if maxevents < 0 {
        object_error(
            PyExc_ValueError, f"Length of eventlist must be 0 or positive, got {maxevents}"
        );
        return NULL;
    }
    timeout: i64 = 0;
    has_timeout = otimeout != Py_None;
    timeout_record = timespec();
    if has_timeout {
        if _PyTime_FromSecondsObject(&mut timeout, otimeout, ROUND_TIMEOUT) < 0 {
            object_error(
                PyExc_TypeError,
                f"timeout argument must be a number or None, got {type_name(
                    otimeout
                ).rsplit(
                    '.', 1
                )[-1]}"
            );
            return NULL;
        }
        if _PyTime_AsTimespec(timeout, &mut timeout_record) == -1 {
            return NULL;
        }
        if timeout_record.tv_sec < 0 {
            object_error(PyExc_ValueError, "timeout must be positive or None");
            return NULL;
        }
    }
    kevent_type = jacpy_binding_state_get(module_of(receiver), KEVENT_TYPE);
    nchanges = 0;
    changes = ptr[kevent_record]();
    if changelist != Py_None {
        seq = PySequence_Fast(changelist, "changelist is not iterable");
        if not seq {
            return NULL;
        }
        size = int(jacpy_fast_size(seq));
        if size > INT_MAX {
            jacpy_release(seq);
            object_error(PyExc_OverflowError, "changelist is too long");
            return NULL;
        }
        nchanges = size;
        changes = ptr[kevent_record](PyMem_Malloc(u64(max(nchanges, 1) * KEVENT_SIZE)));
        if changes.is_null() {
            jacpy_release(seq);
            return PyErr_NoMemory();
        }
        for i in range(nchanges) {
            ei = jacpy_fast_item(seq, i64(i));
            event_state = kevent_of(ei)
                if jacpy_binding_matches(ei, kevent_token.handle) != 0
                else None;
            jacpy_release(ei);
            if event_state is None {
                if not PyErr_Occurred() {
                    object_error(
                        PyExc_TypeError,
                        "changelist must be an iterable of select.kevent objects"
                    );
                }
                PyMem_Free(ptr(changes));
                jacpy_release(seq);
                return NULL;
            }
            (changes + i).view(1)[0] = event_state.record.view(1)[0];
        }
        jacpy_release(seq);
    }
    events = ptr[kevent_record]();
    if maxevents > 0 {
        events = ptr[kevent_record](PyMem_Malloc(u64(int(maxevents) * KEVENT_SIZE)));
        if events.is_null() {
            PyMem_Free(ptr(changes));
            return PyErr_NoMemory();
        }
    }
    # The timespec kevent() reads, in memory the call can see.
    spec_memory = PyMem_Calloc(1, u64(TIMESPEC_SIZE));
    if not spec_memory {
        PyMem_Free(ptr(changes));
        PyMem_Free(ptr(events));
        return PyErr_NoMemory();
    }
    spec = ptr[timespec](spec_memory);
    spec.view(1)[0] = timeout_record;
    deadline: i64 = 0;
    if has_timeout {
        deadline = _PyDeadline_Init(timeout);
    }
    gotevents: i32 = 0;
    failed = False;
    while True {
        thread = PyEval_SaveThread();
        jacpy_set_errno(0);
        gotevents = kevent(
            state.kqfd,
            changes,
            i32(nchanges),
            events,
            maxevents,
            ptr(spec) if has_timeout else ptr()
        );
        PyEval_RestoreThread(thread);
        if jacpy_errno() != EINTR {
            break;
        }
        if PyErr_CheckSignals() != 0 {
            failed = True;
            break;
        }
        if has_timeout {
            timeout = _PyDeadline_Get(deadline);
            if timeout < 0 {
                gotevents = 0;
                break;
            }
            if _PyTime_AsTimespec(timeout, &mut timeout_record) == -1 {
                failed = True;
                break;
            }
            spec.view(1)[0] = timeout_record;
        }
    }
    result = NULL;
    if not failed {
        if gotevents == -1 {
            os_error();
        } else {
            result = PyList_New(i64(gotevents));
            if result {
                for i in range(int(gotevents)) {
                    item = new_kevent(kevent_type, (events + i).view(1)[0]);
                    if not item {
                        jacpy_release(result);
                        result = NULL;
                        break;
                    }
                    PyList_SetItem(result, i64(i), item);
                }
            }
        }
    }
    PyMem_Free(spec_memory);
    PyMem_Free(ptr(changes));
    PyMem_Free(ptr(events));
    return result;
}
