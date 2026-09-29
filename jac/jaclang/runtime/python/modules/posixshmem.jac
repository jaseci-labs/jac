"""POSIX shared memory objects: shm_open() and shm_unlink().

Derived from CPython 3.14.6 Modules/_multiprocessing/posixshmem.c; see
../LICENSE.cpython. Both calls run with the GIL released and are retried on
EINTR unless a signal handler raises.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_errno,
    NULL,
    Py_NewRef,
    PyErr_CheckSignals,
    PyErr_SetFromErrnoWithFilenameObject,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_OSError,
    PyExc_ValueError,
    PyObject,
    PyUnicode_AsUTF8AndSize
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.converters { borrowed_none }
import from jaclang.runtime.python.modules.errno_constants { EINTR }
import from c {
    def shm_unlink(name: ptr[u8]) -> i32;  def strlen(text: ptr[u8]) -> u64;
    # macOS declares shm_open() variadic, reading the mode only with O_CREAT;
    # glibc declares the mode a fixed mode_t, which the x86_64 and aarch64
    # Linux ABIs pass in the same register as a variadic int.
    def shm_open(name: ptr[u8], flags: i32, *args: any) -> i32;
}

# The UTF-8 name of path, or a null pointer with the error set when it cannot
# be encoded or holds a NUL.
def:priv shm_name(path: ptr[PyObject]) -> ptr[u8] {
    size: i64 = 0;
    name = PyUnicode_AsUTF8AndSize(path, &mut size);
    if name.is_null() {
        return name;
    }
    if i64(strlen(name)) != size {
        object_error(PyExc_ValueError, "embedded null character");
        return ptr[u8]();
    }
    return name;
}

def _posixshmem_shm_open_impl(
    module: ptr[PyObject], path: ptr[PyObject], flags: i32, mode: i32
) -> i32 {
    name = shm_name(path);
    if name.is_null() {
        return i32(-1);
    }
    fd: i32 = 0;
    interrupted: i32 = 0;
    while True {
        thread = PyEval_SaveThread();
        fd = shm_open(name, flags, mode);
        PyEval_RestoreThread(thread);
        if not (fd < 0 and jacpy_errno() == EINTR) {
            break;
        }
        interrupted = PyErr_CheckSignals();
        if interrupted != 0 {
            break;
        }
    }
    if fd < 0 {
        if interrupted == 0 {
            PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, path);
        }
        return i32(-1);
    }
    return fd;
}

def _posixshmem_shm_unlink_impl(
    module: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    name = shm_name(path);
    if name.is_null() {
        return NULL;
    }
    status = i32(0);
    interrupted: i32 = 0;
    while True {
        thread = PyEval_SaveThread();
        status = shm_unlink(name);
        PyEval_RestoreThread(thread);
        if not (status < 0 and jacpy_errno() == EINTR) {
            break;
        }
        interrupted = PyErr_CheckSignals();
        if interrupted != 0 {
            break;
        }
    }
    if status < 0 {
        if interrupted == 0 {
            PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, path);
        }
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}
