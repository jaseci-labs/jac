"""SHA-2 hash objects over HACL*; derived from CPython 3.14.6 Modules/sha2module.c.

See ../LICENSE.cpython. The HACL* library stays C: CPython's
Modules/_hacl/libHacl_Hash_SHA2.a, which the registry links for _sha2.
SHA-224 and SHA-256 share the 32-bit HACL* state and SHA256Type's methods;
SHA-384 and SHA-512 share the 64-bit state and SHA512Type's. digest() runs the
wide variant and keeps the object's digest size, as the C module does.
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
    def _Py_LibHacl_Hacl_Hash_SHA2_malloc_224 -> ptr;  def _Py_LibHacl_Hacl_Hash_SHA2_malloc_256 -> ptr;  def _Py_LibHacl_Hacl_Hash_SHA2_malloc_384 -> ptr;  def _Py_LibHacl_Hacl_Hash_SHA2_malloc_512 -> ptr;  def _Py_LibHacl_Hacl_Hash_SHA2_copy_256(
        state: ptr
    ) -> ptr;  def _Py_LibHacl_Hacl_Hash_SHA2_copy_512(state: ptr) -> ptr;  def _Py_LibHacl_Hacl_Hash_SHA2_update_256(
        state: ptr, input: ptr, input_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_SHA2_update_512(
        state: ptr, input: ptr, input_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_SHA2_digest_256(state: ptr, output: ptr);  def _Py_LibHacl_Hacl_Hash_SHA2_digest_512(
        state: ptr, output: ptr
    );  def _Py_LibHacl_Hacl_Hash_SHA2_free_256(state: ptr);  def _Py_LibHacl_Hacl_Hash_SHA2_free_512(
        state: ptr
    );
}

glob SHA256Type_token = ClassToken(),
     SHA512Type_token = ClassToken();

glob SHA256_BLOCKSIZE: i64 = 64,
     SHA256_DIGESTSIZE: i64 = 32,
     SHA512_BLOCKSIZE: i64 = 128,
     SHA512_DIGESTSIZE: i64 = 64,
     SHA224_TYPE: int = 0,
     SHA256_TYPE: int = 1,
     SHA384_TYPE: int = 2,
     SHA512_TYPE: int = 3;

"""A SHA-2 object's state; `wide` selects the 64-bit (SHA-384/512) HACL* state."""
obj SHA2State(NativeState) {
    has lock: HashLock,
        hash_state: ptr = ptr(),
        digestsize: i64 = 0,
        wide: bool = False;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        if self.hash_state {
            if self.wide {
                _Py_LibHacl_Hacl_Hash_SHA2_free_512(self.hash_state);
            } else {
                _Py_LibHacl_Hacl_Hash_SHA2_free_256(self.hash_state);
            }
        }
    }
}

"""update_256(): the error code is ignored; SHA-2-256's 2^61 - 1 byte limit
takes a billion years to reach."""
def:priv update_256(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_SHA2_update_256(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor += UINT32_MAX;
    }
    _Py_LibHacl_Hacl_Hash_SHA2_update_256(hacl, cursor, u32(remaining));
}

"""update_512(): the error code is ignored; SHA-2-512's 2^64 - 1 byte limit
takes a billion years to reach."""
def:priv update_512(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_SHA2_update_512(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor += UINT32_MAX;
    }
    _Py_LibHacl_Hacl_Hash_SHA2_update_512(hacl, cursor, u32(remaining));
}

def:priv digest_256(hacl: ptr, output: ptr) -> i64 {
    _Py_LibHacl_Hacl_Hash_SHA2_digest_256(hacl, output);
    return SHA256_DIGESTSIZE;
}

def:priv digest_512(hacl: ptr, output: ptr) -> i64 {
    _Py_LibHacl_Hacl_Hash_SHA2_digest_512(hacl, output);
    return SHA512_DIGESTSIZE;
}

def sha2_of(instance: ptr[PyObject], token: ClassToken) -> SHA2State | None {
    state = hash_state_of(instance, token);
    if isinstance(state, SHA2State) {
        return state;
    }
    return None;
}

"""A new SHA-2 object of `cls` owning the HACL* state `hacl`; NULL with
MemoryError when the state could not be allocated."""
def:priv new_sha2_object(
    cls: ptr[PyObject], token: ClassToken, hacl: ptr, digestsize: i64, wide: bool
) -> ptr[PyObject] {
    if not hacl {
        PyErr_NoMemory();
        return NULL;
    }
    return hash_object_new(
        cls,
        token,
        SHA2State(hash_state=hacl, lock=HashLock(), digestsize=digestsize, wide=wide)
    );
}

def:priv copy_sha2(receiver: ptr[PyObject], token: ClassToken) -> ptr[PyObject] {
    state = sha2_of(receiver, token);
    if state is None {
        return NULL;
    }
    state.lock.enter();
    hacl = _Py_LibHacl_Hacl_Hash_SHA2_copy_512(state.hash_state)
        if state.wide
        else _Py_LibHacl_Hacl_Hash_SHA2_copy_256(state.hash_state);
    state.lock.leave();
    return new_sha2_object(
        Py_TYPE(receiver), token, hacl, state.digestsize, state.wide
    );
}

def:priv digest_sha2(
    receiver: ptr[PyObject], token: ClassToken, as_hex: bool
) -> ptr[PyObject] {
    state = sha2_of(receiver, token);
    if state is None {
        return NULL;
    }
    if state.wide {
        return hash_digest(
            state.lock,
            state.hash_state,
            SHA512_DIGESTSIZE,
            state.digestsize,
            digest_512,
            as_hex
        );
    }
    return hash_digest(
        state.lock,
        state.hash_state,
        SHA256_DIGESTSIZE,
        state.digestsize,
        digest_256,
        as_hex
    );
}

def SHA256Type_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    return copy_sha2(receiver, SHA256Type_token);
}

def SHA512Type_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    return copy_sha2(receiver, SHA512Type_token);
}

def SHA256Type_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_sha2(receiver, SHA256Type_token, False);
}

def SHA512Type_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_sha2(receiver, SHA512Type_token, False);
}

def SHA256Type_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_sha2(receiver, SHA256Type_token, True);
}

def SHA512Type_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_sha2(receiver, SHA512Type_token, True);
}

def SHA256Type_update_impl(
    receiver: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    state = sha2_of(receiver, SHA256Type_token);
    if state is None {
        return NULL;
    }
    return hash_update(state.lock, state.hash_state, obj_, update_256);
}

def SHA512Type_update_impl(
    receiver: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    state = sha2_of(receiver, SHA512Type_token);
    if state is None {
        return NULL;
    }
    return hash_update(state.lock, state.hash_state, obj_, update_512);
}

"""The module-level constructors: a new object of the module's `slot` type,
fed the initial data when there is any."""
def:priv new_sha2(
    module: ptr[PyObject],
    slot: int,
    data: ptr[PyObject],
    string_obj: ptr[PyObject],
    digestsize: i64
) -> ptr[PyObject] {
    (given, string) = data_argument(data, string_obj);
    if given < 0 {
        return NULL;
    }
    wide = slot == SHA384_TYPE or slot == SHA512_TYPE;
    token = SHA512Type_token if wide else SHA256Type_token;
    hacl = ptr();
    if slot == SHA224_TYPE {
        hacl = _Py_LibHacl_Hacl_Hash_SHA2_malloc_224();
    } elif slot == SHA256_TYPE {
        hacl = _Py_LibHacl_Hacl_Hash_SHA2_malloc_256();
    } elif slot == SHA384_TYPE {
        hacl = _Py_LibHacl_Hacl_Hash_SHA2_malloc_384();
    } else {
        hacl = _Py_LibHacl_Hacl_Hash_SHA2_malloc_512();
    }
    instance = new_sha2_object(
        jacpy_binding_state_get(module, i64(slot)), token, hacl, digestsize, wide
    );
    if not instance {
        return NULL;
    }
    if given == 1 {
        state = sha2_of(instance, token);
        fed = False;
        if state is not None {
            if wide {
                fed = hash_initial_data(state.hash_state, string, update_512);
            } else {
                fed = hash_initial_data(state.hash_state, string, update_256);
            }
        }
        if not fed {
            jacpy_release(instance);
            return NULL;
        }
    }
    return instance;
}

def _sha2_sha256_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return new_sha2(module, SHA256_TYPE, data, string_obj, 32);
}

def _sha2_sha224_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return new_sha2(module, SHA224_TYPE, data, string_obj, 28);
}

def _sha2_sha512_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return new_sha2(module, SHA512_TYPE, data, string_obj, 64);
}

def _sha2_sha384_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return new_sha2(module, SHA384_TYPE, data, string_obj, 48);
}
