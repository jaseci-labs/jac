"""SHA1 hash objects over HACL*; derived from CPython 3.14.6 Modules/sha1module.c.

See ../LICENSE.cpython. The HACL* library stays C: CPython's
Modules/_hacl/libHacl_Hash_SHA1.a, which the registry links for _sha1.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_NoMemory,
    PyObject,
    Py_TYPE,
    jacpy_offset,
    jacpy_release
}
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.modules.hashlib {
    HashLock,
    UINT32_MAX,
    data_argument,
    hash_digest,
    hash_initial_data,
    hash_object_new,
    hash_state_of,
    hash_update
}
import from c {
    def _Py_LibHacl_Hacl_Hash_SHA1_malloc -> ptr;  def _Py_LibHacl_Hacl_Hash_SHA1_update(
        state: ptr, chunk: ptr, chunk_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_SHA1_digest(state: ptr, output: ptr);  def _Py_LibHacl_Hacl_Hash_SHA1_free(
        state: ptr
    );  def _Py_LibHacl_Hacl_Hash_SHA1_copy(state: ptr) -> ptr;
}

glob SHA1Type_token = ClassToken();

glob SHA1_BLOCKSIZE: i64 = 64,
     SHA1_DIGESTSIZE: i64 = 20;

obj SHA1State(NativeState) {
    has lock: HashLock,
        hash_state: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        if self.hash_state {
            _Py_LibHacl_Hacl_Hash_SHA1_free(self.hash_state);
        }
    }
}

"""update(): the HACL* update over 4 GiB chunks. The error code is ignored:
SHA-1's 2^61 - 1 byte limit takes a billion years to reach."""
def:priv sha1_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_SHA1_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor = jacpy_offset(cursor, UINT32_MAX);
    }
    _Py_LibHacl_Hacl_Hash_SHA1_update(hacl, cursor, u32(remaining));
}

def:priv sha1_digest(hacl: ptr, output: ptr) -> i64 {
    _Py_LibHacl_Hacl_Hash_SHA1_digest(hacl, output);
    return SHA1_DIGESTSIZE;
}

def:priv sha1_of(instance: ptr[PyObject]) -> SHA1State | None {
    state = hash_state_of(instance, SHA1Type_token);
    if isinstance(state, SHA1State) {
        return state;
    }
    return None;
}

"""newSHA1object() owning the HACL* state `hacl`; NULL with MemoryError when
the state could not be allocated."""
def:priv new_sha1_object(cls: ptr[PyObject], hacl: ptr) -> ptr[PyObject] {
    if not hacl {
        PyErr_NoMemory();
        return NULL;
    }
    return hash_object_new(
        cls, SHA1Type_token, SHA1State(hash_state=hacl, lock=HashLock())
    );
}

def SHA1Type_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    state = sha1_of(receiver);
    if state is None {
        return NULL;
    }
    state.lock.enter();
    hacl = _Py_LibHacl_Hacl_Hash_SHA1_copy(state.hash_state);
    state.lock.leave();
    return new_sha1_object(Py_TYPE(receiver), hacl);
}

def SHA1Type_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = sha1_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_digest(
        state.lock, state.hash_state, SHA1_DIGESTSIZE, -1, sha1_digest, False
    );
}

def SHA1Type_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = sha1_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_digest(
        state.lock, state.hash_state, SHA1_DIGESTSIZE, -1, sha1_digest, True
    );
}

def SHA1Type_update_impl(
    receiver: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    state = sha1_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_update(state.lock, state.hash_state, obj_, sha1_update);
}

def _sha1_sha1_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    (given, string) = data_argument(data, string_obj);
    if given < 0 {
        return NULL;
    }
    instance = new_sha1_object(
        jacpy_binding_state_get(module, 0), _Py_LibHacl_Hacl_Hash_SHA1_malloc()
    );
    if not instance {
        return NULL;
    }
    if given == 1 {
        state = sha1_of(instance);
        if state is None
            or not hash_initial_data(state.hash_state, string, sha1_update) {
            jacpy_release(instance);
            return NULL;
        }
    }
    return instance;
}
