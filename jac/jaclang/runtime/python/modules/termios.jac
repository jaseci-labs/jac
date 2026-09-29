"""POSIX terminal I/O control.

Derived from CPython 3.14.6 Modules/termios.c; see ../LICENSE.cpython.
struct termios is read and written in place in C memory: the flag words and
speeds through termios_records.<os>.jac, the control characters at its c_cc
offset. termios.error is module state slot 0. The constants come from
termios_constants.<os>.jac.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_bytes_from_memory,
    jacpy_ioctl_pointer,
    jacpy_is_bytes,
    jacpy_is_list,
    jacpy_is_long,
    jacpy_release,
    NULL,
    Py_NewRef,
    PyBytes_AsString,
    PyBytes_Size,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_OverflowError,
    PyExc_TypeError,
    PyList_GetItem,
    PyList_New,
    PyList_SetItem,
    PyList_Size,
    PyLong_AsLong,
    PyLong_FromLong,
    PyMem_Calloc,
    PyMem_Free,
    PyObject,
    PySequence_Check,
    PySequence_GetItem,
    PySequence_Size,
    PyTuple_New,
    PyTuple_SetItem
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.converters { borrowed_none }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.modules.termios_records {
    TERMIOS_SIZE,
    CC_OFFSET,
    flags_of,
    set_flags,
    input_speed,
    output_speed,
    set_input_speed,
    set_output_speed
}
import from jaclang.runtime.python.modules.termios_constants {
    ICANON,
    NCCS,
    TIOCGWINSZ,
    TIOCSWINSZ,
    VMIN,
    VTIME
}
import from c {
    obj winsize {
        has ws_row: u16 = 0,
            ws_col: u16 = 0,
            ws_xpixel: u16 = 0,
            ws_ypixel: u16 = 0;
    }  def tcgetattr(fd: i32, mode: ptr) -> i32;  def tcsetattr(
        fd: i32, when: i32, mode: ptr
    ) -> i32;  def tcsendbreak(fd: i32, duration: i32) -> i32;  def tcdrain(
        fd: i32
    ) -> i32;  def tcflush(fd: i32, queue: i32) -> i32;  def tcflow(
        fd: i32, action: i32
    ) -> i32;
}

def:priv termios_error(module: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_SetFromErrno(jacpy_binding_state_get(module, 0));
    return NULL;
}

def:priv none -> ptr[PyObject] {
    return Py_NewRef(borrowed_none());
}

# A zeroed struct termios; some C libraries leave fields uninitialized.
def:priv new_mode -> ptr {
    mode = PyMem_Calloc(u64(1), u64(TERMIOS_SIZE));
    if not mode {
        PyErr_NoMemory();
    }
    return mode;
}

def:priv control_characters(mode: ptr) -> ptr[u8] {
    return ptr[u8](mode) + CC_OFFSET;
}

def:priv tcgetattr_list(mode: ptr) -> ptr[PyObject] {
    ispeed = input_speed(mode);
    ospeed = output_speed(mode);
    cc = PyList_New(NCCS);
    if not cc {
        return NULL;
    }
    chars = control_characters(mode);
    for index in range(int(NCCS)) {
        item = jacpy_bytes_from_memory(chars + index, 1);
        if not item {
            jacpy_release(cc);
            return NULL;
        }
        PyList_SetItem(cc, i64(index), item);
    }
    flags = flags_of(mode);
    # MIN and TIME share slots with EOF and EOL on some systems, so they are
    # integers only in noncanonical mode.
    if (flags[3] & ICANON) == 0 {
        values = chars.view(int(NCCS));
        for slot in [VMIN, VTIME] {
            item = PyLong_FromLong(i64(values[slot]));
            if not item or PyList_SetItem(cc, slot, item) < 0 {
                jacpy_release(cc);
                return NULL;
            }
        }
    }
    result = PyList_New(7);
    if not result {
        jacpy_release(cc);
        return NULL;
    }
    longs = flags + [ispeed, ospeed];
    for index in range(6) {
        item = PyLong_FromLong(longs[index]);
        if not item {
            jacpy_release(result);
            jacpy_release(cc);
            return NULL;
        }
        PyList_SetItem(result, i64(index), item);
    }
    PyList_SetItem(result, 6, cc);
    return result;
}

def termios_tcgetattr_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    mode = new_mode();
    if not mode {
        return NULL;
    }
    thread = PyEval_SaveThread();
    status = tcgetattr(fd, mode);
    PyEval_RestoreThread(thread);
    result = termios_error(module) if status == -1 else tcgetattr_list(mode);
    PyMem_Free(mode);
    return result;
}

# SET_FROM_LIST: the item as a C long.
def:priv list_long(term: ptr[PyObject], index: i64) -> tuple[bool, i64] {
    number = PyLong_AsLong(PyList_GetItem(term, index));
    if number == -1 and PyErr_Occurred() {
        return (False, i64(0));
    }
    return (True, number);
}

def:priv set_mode(
    module: ptr[PyObject], fd: i32, when: i32, term: ptr[PyObject], mode: ptr
) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    status = tcgetattr(fd, mode);
    PyEval_RestoreThread(thread);
    if status == -1 {
        return termios_error(module);
    }
    longs: list[i64] = [];
    for index in range(6) {
        (ok, number) = list_long(term, i64(index));
        if not ok {
            return NULL;
        }
        longs.append(number);
    }
    set_flags(mode, longs[0:4]);
    cc = PyList_GetItem(term, 6);
    if jacpy_is_list(cc) == 0 or PyList_Size(cc) != NCCS {
        object_error(
            PyExc_TypeError, f"tcsetattr: attributes[6] must be {NCCS} element list"
        );
        return NULL;
    }
    chars = control_characters(mode).view(int(NCCS));
    for index in range(int(NCCS)) {
        item = PyList_GetItem(cc, i64(index));
        if jacpy_is_bytes(item) != 0 and PyBytes_Size(item) == 1 {
            chars[index] = PyBytes_AsString(item).view(1)[0];
        } elif jacpy_is_long(item) != 0 {
            number = PyLong_AsLong(item);
            if number == -1 and PyErr_Occurred() {
                return NULL;
            }
            chars[index] = u8.wrap(number);
        } else {
            object_error(
                PyExc_TypeError,
                "tcsetattr: elements of attributes must be bytes objects of length 1 or integers"
            );
            return NULL;
        }
    }
    if set_input_speed(mode, longs[4]) == -1 {
        return termios_error(module);
    }
    if set_output_speed(mode, longs[5]) == -1 {
        return termios_error(module);
    }
    thread = PyEval_SaveThread();
    status = tcsetattr(fd, when, mode);
    PyEval_RestoreThread(thread);
    if status == -1 {
        return termios_error(module);
    }
    return none();
}

def termios_tcsetattr_impl(
    module: ptr[PyObject], fd: i32, when: i32, term: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_list(term) == 0 or PyList_Size(term) != 7 {
        object_error(PyExc_TypeError, "tcsetattr, arg 3: must be 7 element list");
        return NULL;
    }
    mode = new_mode();
    if not mode {
        return NULL;
    }
    result = set_mode(module, fd, when, term, mode);
    PyMem_Free(mode);
    return result;
}

def termios_tcsendbreak_impl(
    module: ptr[PyObject], fd: i32, duration: i32
) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    status = tcsendbreak(fd, duration);
    PyEval_RestoreThread(thread);
    return termios_error(module) if status == -1 else none();
}

def termios_tcdrain_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    status = tcdrain(fd);
    PyEval_RestoreThread(thread);
    return termios_error(module) if status == -1 else none();
}

def termios_tcflush_impl(module: ptr[PyObject], fd: i32, queue: i32) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    status = tcflush(fd, queue);
    PyEval_RestoreThread(thread);
    return termios_error(module) if status == -1 else none();
}

def termios_tcflow_impl(module: ptr[PyObject], fd: i32, action: i32) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    status = tcflow(fd, action);
    PyEval_RestoreThread(thread);
    return termios_error(module) if status == -1 else none();
}

def:priv new_winsize -> ptr {
    size = PyMem_Calloc(u64(1), u64(8));
    if not size {
        PyErr_NoMemory();
    }
    return size;
}

def:priv winsize_tuple(size: ptr) -> ptr[PyObject] {
    record = ptr[winsize](size).view(1);
    result = PyTuple_New(2);
    if not result {
        return NULL;
    }
    PyTuple_SetItem(result, 0, PyLong_FromLong(i64(record[0].ws_row)));
    PyTuple_SetItem(result, 1, PyLong_FromLong(i64(record[0].ws_col)));
    if PyErr_Occurred() {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def termios_tcgetwinsize_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    size = new_winsize();
    if not size {
        return NULL;
    }
    thread = PyEval_SaveThread();
    status = jacpy_ioctl_pointer(fd, u64.wrap(TIOCGWINSZ), size);
    PyEval_RestoreThread(thread);
    result = termios_error(module) if status == -1 else winsize_tuple(size);
    PyMem_Free(size);
    return result;
}

# The sequence item as a C long; the error, if any, stays set.
def:priv sequence_long(winsz: ptr[PyObject], index: i64) -> tuple[bool, i64] {
    item = PySequence_GetItem(winsz, index);
    number = PyLong_AsLong(item);
    failed = number == -1 and bool(PyErr_Occurred());
    jacpy_release(item);
    return (not failed, number);
}

def:priv set_winsize(
    module: ptr[PyObject], fd: i32, rows: i64, columns: i64, size: ptr
) -> ptr[PyObject] {
    # The old winsize may have more fields, such as xpixel and ypixel.
    if jacpy_ioctl_pointer(fd, u64.wrap(TIOCGWINSZ), size) == -1 {
        return termios_error(module);
    }
    record = ptr[winsize](size).view(1);
    record[0].ws_row = u16.wrap(rows);
    record[0].ws_col = u16.wrap(columns);
    if i64(record[0].ws_row) != rows or i64(record[0].ws_col) != columns {
        object_error(PyExc_OverflowError, "winsize value(s) out of range.");
        return NULL;
    }
    thread = PyEval_SaveThread();
    status = jacpy_ioctl_pointer(fd, u64.wrap(TIOCSWINSZ), size);
    PyEval_RestoreThread(thread);
    return termios_error(module) if status == -1 else none();
}

def termios_tcsetwinsize_impl(
    module: ptr[PyObject], fd: i32, winsz: ptr[PyObject]
) -> ptr[PyObject] {
    if PySequence_Check(winsz) == 0 or PySequence_Size(winsz) != 2 {
        object_error(
            PyExc_TypeError, "tcsetwinsize, arg 2: must be a two-item sequence"
        );
        return NULL;
    }
    (rows_ok, rows) = sequence_long(winsz, 0);
    if not rows_ok {
        return NULL;
    }
    (columns_ok, columns) = sequence_long(winsz, 1);
    if not columns_ok {
        return NULL;
    }
    size = new_winsize();
    if not size {
        return NULL;
    }
    result = set_winsize(module, fd, rows, columns, size);
    PyMem_Free(size);
    return result;
}
