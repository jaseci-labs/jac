"""The parts the HACL*-backed hash modules share; derived from CPython 3.14.6
Modules/hashlib.h. See ../LICENSE.cpython.

A hash object keeps its HACL* state as native state under a ClassToken.
HACL* takes 32-bit lengths, so each module wraps its update function in a
loop over 4 GiB chunks and passes that wrapper here. An update of at least
HASHLIB_GIL_MINSIZE bytes runs with the GIL released, and from then on the
object takes its lock around every access to the HACL* state, as
ENTER_HASHLIB and LEAVE_HASHLIB do. The lock is a PyThread lock, allocated
when the object first needs it.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_NoMemory,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_BufferError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyObject_CheckBuffer,
    PyThread_acquire_lock,
    PyThread_allocate_lock,
    PyThread_free_lock,
    PyThread_release_lock,
    Py_NewRef,
    Py_TYPE,
    _Py_strhex,
    jacpy_bytes_from_memory,
    jacpy_crypto_compare,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_unicode_ascii
}
import from jaclang.runtime.python.capi { object_error, type_name }
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { ClassToken, borrowed_none }
import from jaclang.runtime.python.bindings.type { jacpy_binding_allocate }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}

glob HASHLIB_GIL_MINSIZE: i64 = 2048,
     UINT32_MAX: i64 = 0xFFFFFFFF;

"""The mutex of a hash object and its use_mutex flag."""
obj HashLock {
    has use_mutex: bool = False,
        lock: ptr = ptr();

    """ENTER_HASHLIB: take the lock once the object uses it, releasing the GIL
    while waiting for it."""
    def enter {
        if self.use_mutex and PyThread_acquire_lock(self.lock, 0) == 0 {
            thread = PyEval_SaveThread();
            PyThread_acquire_lock(self.lock, 1);
            PyEval_RestoreThread(thread);
        }
    }

    """LEAVE_HASHLIB."""
    def leave {
        if self.use_mutex {
            PyThread_release_lock(self.lock);
        }
    }

    """Switch the object to locked access; False with MemoryError set when no
    lock can be allocated."""
    def enable -> bool {
        if not self.lock {
            self.lock = PyThread_allocate_lock();
            if not self.lock {
                PyErr_NoMemory();
                return False;
            }
        }
        self.use_mutex = True;
        return True;
    }

    def drop {
        if self.lock {
            PyThread_free_lock(self.lock);
        }
    }
}

"""_Py_hashlib_data_argument(): the object to hash, from the `data` and
`string` arguments. (1, object) when one was given, (0, NULL) when neither
was, and (-1, NULL) with TypeError set when both were."""
def data_argument(
    data: ptr[PyObject], string: ptr[PyObject]
) -> tuple[int, ptr[PyObject]] {
    if data and not string {
        return (1, data);
    }
    if string and not data {
        return (1, string);
    }
    if not data and not string {
        return (0, NULL);
    }
    object_error(
        PyExc_TypeError,
        "'data' and 'string' are mutually exclusive and support for 'string' keyword parameter is slated for removal in a future version."
    );
    return (-1, NULL);
}

"""GET_BUFFER_VIEW_OR_ERROR: a simple, one-dimensional view of value, or None
with the error set."""
def hash_buffer(value: ptr[PyObject]) -> BufferArgument | None {
    if jacpy_is_unicode(value) != 0 {
        object_error(PyExc_TypeError, "Strings must be encoded before hashing");
        return None;
    }
    if PyObject_CheckBuffer(value) == 0 {
        object_error(PyExc_TypeError, "object supporting the buffer API required");
        return None;
    }
    view = BufferArgument();
    if not view.acquire(value) {
        return None;
    }
    if view.dimensions() > 1 {
        object_error(PyExc_BufferError, "Buffer must be single dimension");
        view.close();
        return None;
    }
    return view;
}

"""A new instance of `cls` owning `state` as its native state, or NULL."""
def hash_object_new(
    cls: ptr[PyObject], token: ClassToken, state: NativeState
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(cls);
    if not instance {
        return NULL;
    }
    if jacpy_binding_native_set(instance, token.definition_of(cls), state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

"""The native state of a hash object, or None with SystemError set."""
def hash_state_of(instance: ptr[PyObject], token: ClassToken) -> NativeState | None {
    definition = token.definition_of(Py_TYPE(instance));
    if jacpy_binding_native_present(instance, definition) != 0 {
        return jacpy_binding_native_get(instance, definition);
    }
    object_error(PyExc_SystemError, "hash object state is unavailable");
    return None;
}

"""Feed a constructor's initial data into a HACL* state. The new object is not
shared yet, so large data runs with the GIL released but takes no lock."""
def hash_initial_data(
    hacl: ptr, data: ptr[PyObject], update: Callable[[ptr, ptr, i64], None]
) -> bool {
    view = hash_buffer(data);
    if view is None {
        return False;
    }
    address = view.address();
    size = view.size();
    if size >= HASHLIB_GIL_MINSIZE {
        thread = PyEval_SaveThread();
        update(hacl, address, size);
        PyEval_RestoreThread(thread);
    } else {
        update(hacl, address, size);
    }
    view.close();
    return True;
}

"""update() of a hash object. From HASHLIB_GIL_MINSIZE bytes the object
switches to locked access, and a locked update runs with the GIL released."""
def hash_update(
    lock: HashLock,
    hacl: ptr,
    value: ptr[PyObject],
    update: Callable[[ptr, ptr, i64], None]
) -> ptr[PyObject] {
    view = hash_buffer(value);
    if view is None {
        return NULL;
    }
    address = view.address();
    size = view.size();
    if not lock.use_mutex and size >= HASHLIB_GIL_MINSIZE and not lock.enable() {
        view.close();
        return NULL;
    }
    if lock.use_mutex {
        mutex = lock.lock;
        thread = PyEval_SaveThread();
        PyThread_acquire_lock(mutex, 1);
        update(hacl, address, size);
        PyThread_release_lock(mutex);
        PyEval_RestoreThread(thread);
    } else {
        update(hacl, address, size);
    }
    view.close();
    return Py_NewRef(borrowed_none());
}

"""digest() or hexdigest(): `digest` writes into a buffer of `capacity` bytes
and returns how many it wrote; `size`, when not negative, keeps only that
prefix (SHA-224 and SHA-384 truncate the wider state's output)."""
def hash_digest(
    lock: HashLock,
    hacl: ptr,
    capacity: i64,
    size: i64,
    digest: Callable[[ptr, ptr], i64],
    as_hex: bool
) -> ptr[PyObject] {
    output = PyMem_Malloc(u64(capacity));
    if not output {
        PyErr_NoMemory();
        return NULL;
    }
    lock.enter();
    written = digest(hacl, output);
    lock.leave();
    length = size if size >= 0 else written;
    result = _Py_strhex(output, length)
        if as_hex
        else jacpy_bytes_from_memory(output, length);
    PyMem_Free(output);
    return result;
}

"""_tscmp(): whether two buffers are equal, in time that depends only on the
length of the second (CRYPTO_memcmp)."""
def:priv timing_safe_equal(a: ptr, b: ptr, a_size: i64, b_size: i64) -> bool {
    left = a if a_size == b_size else b;
    difference = jacpy_crypto_compare(left, b, b_size);
    return difference == 0 and a_size == b_size;
}

"""compare_digest(a, b) of _operator (_compare_digest) and _hashlib: a == b
without content-dependent timing, for two ASCII str or two buffers."""
def compare_digest(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    ascii = jacpy_is_unicode(a) != 0 and jacpy_is_unicode(b) != 0;
    if ascii {
        if jacpy_unicode_ascii(a) == 0 or jacpy_unicode_ascii(b) == 0 {
            object_error(
                PyExc_TypeError,
                "comparing strings with non-ASCII characters is not supported"
            );
            return NULL;
        }
    } elif PyObject_CheckBuffer(a) == 0 and PyObject_CheckBuffer(b) == 0 {
        object_error(
            PyExc_TypeError,
            "unsupported operand types(s) or combination of types: '"
                + type_name(a)[:100]
                + "' and '"
                + type_name(b)[:100]
                + "'"
        );
        return NULL;
    }
    first = BufferArgument();
    if not first.acquire(a, ascii) {
        return NULL;
    }
    if first.dimensions() > 1 {
        object_error(PyExc_BufferError, "Buffer must be single dimension");
        first.close();
        return NULL;
    }
    second = BufferArgument();
    if not second.acquire(b, ascii) {
        first.close();
        return NULL;
    }
    if second.dimensions() > 1 {
        object_error(PyExc_BufferError, "Buffer must be single dimension");
        first.close();
        second.close();
        return NULL;
    }
    equal = timing_safe_equal(
        first.address(), second.address(), first.size(), second.size()
    );
    first.close();
    second.close();
    return PyBool_FromLong(i64(equal));
}
