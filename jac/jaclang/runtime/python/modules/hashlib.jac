"""The parts the hash modules share; derived from CPython 3.14.6
Modules/hashlib.h. See ../LICENSE.cpython.

A hash object keeps a digest core from na_stdlib/_digest.jac as native state
under a ClassToken. An update of at least HASHLIB_GIL_MINSIZE bytes runs with
the GIL released, and from then on the object takes its lock around every
access to the core, as ENTER_HASHLIB and LEAVE_HASHLIB do. The lock is a
PyThread lock, allocated when the object first needs it.
"""

glob HASHLIB_GIL_MINSIZE: i64 = 2048;

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

"""A hash object's native state: its digest core and, once an update has been
large enough to run without the GIL, its lock."""
obj DigestState(NativeState) {
    has core: DigestCore,
        lock: HashLock | None = None;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
}

"""The digest state of a hash object of `token`, or None with SystemError set."""
def digest_state(instance: ptr[PyObject], token: ClassToken) -> DigestState | None {
    state = hash_state_of(instance, token);
    if isinstance(state, DigestState) {
        return state;
    }
    return None;
}

"""The size of `value` when it is exactly bytes and too small to release the
GIL for, else -1. Such data is hashed in place without a buffer view."""
def small_bytes(value: ptr[PyObject]) -> int {
    if Py_TYPE(value) == addressof(PyBytes_Type) {
        size = jacpy_bytes_length(value);
        if size < HASHLIB_GIL_MINSIZE {
            return int(size);
        }
    }
    return -1;
}

"""Feed a constructor's initial data into a core. The new object is not shared
yet, so large data runs with the GIL released but takes no lock."""
def hash_initial_data(core: DigestCore, data: ptr[PyObject]) -> bool {
    small = small_bytes(data);
    if small >= 0 {
        core.absorb(int(jacpy_bytes_address(data)), small);
        return True;
    }
    view = hash_buffer(data);
    if view is None {
        return False;
    }
    address = int(view.address());
    size = view.size();
    if size >= HASHLIB_GIL_MINSIZE {
        thread = PyEval_SaveThread();
        core.absorb(address, size);
        PyEval_RestoreThread(thread);
    } else {
        core.absorb(address, size);
    }
    view.close();
    return True;
}

"""A new hash object of `cls` owning `core`, fed `data` unless it is NULL."""
def digest_object(
    cls: ptr[PyObject], token: ClassToken, core: DigestCore, data: ptr[PyObject]
) -> ptr[PyObject] {
    instance = hash_object_new(cls, token, DigestState(core=core));
    if instance and data and not hash_initial_data(core, data) {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

"""A module constructor: the `data` or `string` argument fed to a new object."""
def digest_new(
    cls: ptr[PyObject],
    token: ClassToken,
    core: DigestCore | None,
    data: ptr[PyObject],
    string: ptr[PyObject]
) -> ptr[PyObject] {
    value = data;
    if string {
        (given, value) = data_argument(data, string);
        if given < 0 {
            return NULL;
        }
    }
    if core is None {
        object_error(PyExc_SystemError, "bad argument to internal function");
        return NULL;
    }
    return digest_object(cls, token, core, value);
}

"""copy(): a new object of the receiver's type with a snapshot of its core."""
def digest_copy(receiver: ptr[PyObject], token: ClassToken) -> ptr[PyObject] {
    state = digest_state(receiver, token);
    if state is None {
        return NULL;
    }
    lock = state.lock;
    if lock is not None {
        lock.enter();
    }
    core = state.core.clone();
    if lock is not None {
        lock.leave();
    }
    return digest_object(Py_TYPE(receiver), token, core, NULL);
}

"""update(). From HASHLIB_GIL_MINSIZE bytes the object switches to locked
access, and a locked update runs with the GIL released."""
def digest_update(
    receiver: ptr[PyObject], token: ClassToken, value: ptr[PyObject]
) -> ptr[PyObject] {
    state = digest_state(receiver, token);
    if state is None {
        return NULL;
    }
    lock = state.lock;
    small = small_bytes(value) if lock is None else -1;
    if small >= 0 {
        state.core.absorb(int(jacpy_bytes_address(value)), small);
        return Py_NewRef(borrowed_none());
    }
    view = hash_buffer(value);
    if view is None {
        return NULL;
    }
    address = int(view.address());
    size = view.size();
    if lock is None and size >= HASHLIB_GIL_MINSIZE {
        lock = HashLock();
        if not lock.enable() {
            view.close();
            return NULL;
        }
        state.lock = lock;
    }
    if lock is not None {
        mutex = lock.lock;
        thread = PyEval_SaveThread();
        PyThread_acquire_lock(mutex, 1);
        state.core.absorb(address, size);
        PyThread_release_lock(mutex);
        PyEval_RestoreThread(thread);
    } else {
        state.core.absorb(address, size);
    }
    view.close();
    return Py_NewRef(borrowed_none());
}

"""digest() or hexdigest(); `length`, when not negative, squeezes that many
bytes from an extendable-output core (SHAKE)."""
def digest_value(
    receiver: ptr[PyObject], token: ClassToken, as_hex: bool, length: i64 = -1
) -> ptr[PyObject] {
    state = digest_state(receiver, token);
    if state is None {
        return NULL;
    }
    lock = state.lock;
    if lock is not None {
        lock.enter();
    }
    value = state.core.finish() if length < 0 else state.core.squeeze(int(length));
    if lock is not None {
        lock.leave();
    }
    if as_hex {
        return _Py_strhex(ptr(__bytes_data(value)), i64(len(value)));
    }
    return jacpy_bytes_from_payload(value, i64(len(value)));
}

"""A property of a hash object: `which` 0 is name, 1 digest_size, 2 block_size."""
def digest_property(
    instance: ptr[PyObject], token: ClassToken, which: int
) -> ptr[PyObject] {
    state = digest_state(instance, token);
    if state is None {
        return NULL;
    }
    if which == 0 {
        return jacpy_unicode_from_text(state.core.name);
    }
    return PyLong_FromLong(
        i64(state.core.digest_size if which == 1 else state.core.block_size)
    );
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
