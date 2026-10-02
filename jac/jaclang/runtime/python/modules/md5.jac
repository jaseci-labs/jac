"""MD5 hash objects over HACL*; derived from CPython 3.14.6 Modules/md5module.c.

See ../LICENSE.cpython. The HACL* library stays C: CPython's
Modules/_hacl/libHacl_Hash_MD5.a, which the registry links for _md5.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_NoMemory,
    PyObject,
    Py_TYPE,
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
    def _Py_LibHacl_Hacl_Hash_MD5_malloc -> ptr;  def _Py_LibHacl_Hacl_Hash_MD5_update(
        state: ptr, chunk: ptr, chunk_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_MD5_digest(state: ptr, output: ptr);  def _Py_LibHacl_Hacl_Hash_MD5_free(
        state: ptr
    );  def _Py_LibHacl_Hacl_Hash_MD5_copy(state: ptr) -> ptr;
}

glob MD5Type_token = ClassToken();

glob MD5_BLOCKSIZE: i64 = 64,
     MD5_DIGESTSIZE: i64 = 16;

obj MD5State(NativeState) {
    has lock: HashLock,
        hash_state: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        if self.hash_state {
            _Py_LibHacl_Hacl_Hash_MD5_free(self.hash_state);
        }
    }
}

"""update(): the HACL* update over 4 GiB chunks. The error code is ignored:
MD5's 2^61 - 1 byte limit takes a billion years to reach."""
def:priv md5_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_MD5_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor += UINT32_MAX;
    }
    _Py_LibHacl_Hacl_Hash_MD5_update(hacl, cursor, u32(remaining));
}

def:priv md5_digest(hacl: ptr, output: ptr) -> i64 {
    _Py_LibHacl_Hacl_Hash_MD5_digest(hacl, output);
    return MD5_DIGESTSIZE;
}

def:priv md5_of(instance: ptr[PyObject]) -> MD5State | None {
    state = hash_state_of(instance, MD5Type_token);
    if isinstance(state, MD5State) {
        return state;
    }
    return None;
}

"""newMD5object() owning the HACL* state `hacl`; NULL with MemoryError when
the state could not be allocated."""
def:priv new_md5_object(cls: ptr[PyObject], hacl: ptr) -> ptr[PyObject] {
    if not hacl {
        PyErr_NoMemory();
        return NULL;
    }
    return hash_object_new(
        cls, MD5Type_token, MD5State(hash_state=hacl, lock=HashLock())
    );
}

def MD5Type_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    state = md5_of(receiver);
    if state is None {
        return NULL;
    }
    state.lock.enter();
    hacl = _Py_LibHacl_Hacl_Hash_MD5_copy(state.hash_state);
    state.lock.leave();
    return new_md5_object(Py_TYPE(receiver), hacl);
}

def MD5Type_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = md5_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_digest(
        state.lock, state.hash_state, MD5_DIGESTSIZE, -1, md5_digest, False
    );
}

def MD5Type_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = md5_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_digest(
        state.lock, state.hash_state, MD5_DIGESTSIZE, -1, md5_digest, True
    );
}

def MD5Type_update_impl(receiver: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    state = md5_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_update(state.lock, state.hash_state, obj_, md5_update);
}

def _md5_md5_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    (given, string) = data_argument(data, string_obj);
    if given < 0 {
        return NULL;
    }
    instance = new_md5_object(
        jacpy_binding_state_get(module, 0), _Py_LibHacl_Hacl_Hash_MD5_malloc()
    );
    if not instance {
        return NULL;
    }
    if given == 1 {
        state = md5_of(instance);
        if state is None
            or not hash_initial_data(state.hash_state, string, md5_update) {
            jacpy_release(instance);
            return NULL;
        }
    }
    return instance;
}
