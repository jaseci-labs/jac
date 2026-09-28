"""SHA-3 and SHAKE hash objects over HACL*; derived from CPython 3.14.6
Modules/sha3module.c. See ../LICENSE.cpython.

The HACL* library stays C: CPython's Modules/_hacl/libHacl_Hash_SHA3.a, which
the registry links for _sha3. The six types share one implementation; a
type's slot in the module state selects its HACL* algorithm.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_FromStringAndSize,
    PyErr_NoMemory,
    PyLong_FromLong,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyType_GetModule,
    PyUnicode_FromString,
    Py_TYPE,
    _Py_strhex,
    jacpy_bytes_from_memory,
    jacpy_offset,
    jacpy_release
}
import from jaclang.runtime.python.capi { object_error }
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
    def _Py_LibHacl_Hacl_Hash_SHA3_malloc(a: u8) -> ptr;  def _Py_LibHacl_Hacl_Hash_SHA3_free(
        state: ptr
    );  def _Py_LibHacl_Hacl_Hash_SHA3_copy(state: ptr) -> ptr;  def _Py_LibHacl_Hacl_Hash_SHA3_update(
        state: ptr, chunk: ptr, chunk_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_SHA3_digest(state: ptr, output: ptr) -> u8;  def _Py_LibHacl_Hacl_Hash_SHA3_squeeze(
        s: ptr, dst: ptr, l: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_SHA3_block_len(s: ptr) -> u32;  def _Py_LibHacl_Hacl_Hash_SHA3_hash_len(
        s: ptr
    ) -> u32;
}

glob SHA3_token = ClassToken(),
     SHA3_MAX_DIGESTSIZE: i64 = 64;

"""The module-state slot, type name and Spec_Hash_Definitions algorithm of
each type, in the order _sha3_exec creates them."""
glob SHA3_TYPES: list[tuple[str, u8]] = [
         ("sha3_224", u8(9)),
         ("sha3_256", u8(8)),
         ("sha3_384", u8(10)),
         ("sha3_512", u8(11)),
         ("shake_128", u8(12)),
         ("shake_256", u8(13))
     ];

obj SHA3State(NativeState) {
    has lock: HashLock,
        hash_state: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        if self.hash_state {
            _Py_LibHacl_Hacl_Hash_SHA3_free(self.hash_state);
        }
    }
}

"""sha3_update(): the error code is ignored; SHA-3's 2^64 - 1 byte limit takes
a billion years to reach."""
def:priv sha3_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_SHA3_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor = jacpy_offset(cursor, UINT32_MAX);
    }
    _Py_LibHacl_Hacl_Hash_SHA3_update(hacl, cursor, u32(remaining));
}

"""digest() of a fixed-length SHA-3: HACL* fails only for SHAKE, which these
methods never see."""
def:priv sha3_digest(hacl: ptr, output: ptr) -> i64 {
    _Py_LibHacl_Hacl_Hash_SHA3_digest(hacl, output);
    return i64(_Py_LibHacl_Hacl_Hash_SHA3_hash_len(hacl));
}

def:priv sha3_of(instance: ptr[PyObject]) -> SHA3State | None {
    state = hash_state_of(instance, SHA3_token);
    if isinstance(state, SHA3State) {
        return state;
    }
    return None;
}

"""The index of `cls` among the module's six types, or -1."""
def:priv type_index(cls: ptr[PyObject]) -> int {
    module = PyType_GetModule(cls);
    if not module {
        return -1;
    }
    for index in range(len(SHA3_TYPES)) {
        if jacpy_binding_state_get(module, i64(index)) == cls {
            return index;
        }
    }
    return -1;
}

"""A new object of `cls` owning the HACL* state `hacl`; NULL with MemoryError
when the state could not be allocated."""
def:priv new_sha3_object(cls: ptr[PyObject], hacl: ptr) -> ptr[PyObject] {
    if not hacl {
        PyErr_NoMemory();
        return NULL;
    }
    return hash_object_new(
        cls, SHA3_token, SHA3State(hash_state=hacl, lock=HashLock())
    );
}

def py_sha3_new_impl(
    type: ptr[PyObject],
    data_obj: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    (given, data) = data_argument(data_obj, string);
    if given < 0 {
        return NULL;
    }
    index = type_index(type);
    if index < 0 {
        object_error("SystemError", "bad argument to internal function");
        return NULL;
    }
    instance = new_sha3_object(
        type, _Py_LibHacl_Hacl_Hash_SHA3_malloc(SHA3_TYPES[index][1])
    );
    if not instance {
        return NULL;
    }
    if given == 1 {
        state = sha3_of(instance);
        if state is None
            or not hash_initial_data(state.hash_state, data, sha3_update) {
            jacpy_release(instance);
            return NULL;
        }
    }
    return instance;
}

def _sha3_sha3_224_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    state.lock.enter();
    hacl = _Py_LibHacl_Hacl_Hash_SHA3_copy(state.hash_state);
    state.lock.leave();
    return new_sha3_object(Py_TYPE(receiver), hacl);
}

def _sha3_sha3_224_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_digest(
        state.lock, state.hash_state, SHA3_MAX_DIGESTSIZE, -1, sha3_digest, False
    );
}

def _sha3_sha3_224_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_digest(
        state.lock, state.hash_state, SHA3_MAX_DIGESTSIZE, -1, sha3_digest, True
    );
}

def _sha3_sha3_224_update_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_update(state.lock, state.hash_state, data, sha3_update);
}

"""_SHAKE_digest(): squeeze `length` bytes. HACL* fails for an empty output,
so an empty digest is returned without squeezing, as before."""
def:priv shake_digest(
    receiver: ptr[PyObject], length: u64, as_hex: bool
) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    if length >= u64(1 << 29) {
        object_error("ValueError", "length is too large");
        return NULL;
    }
    output = PyMem_Malloc(length);
    if not output {
        PyErr_NoMemory();
        return NULL;
    }
    if length > u64(0) {
        _Py_LibHacl_Hacl_Hash_SHA3_squeeze(state.hash_state, output, u32(length));
    }
    result = _Py_strhex(output, i64(length))
        if as_hex
        else jacpy_bytes_from_memory(output, i64(length));
    PyMem_Free(output);
    return result;
}

def _sha3_shake_128_digest_impl(receiver: ptr[PyObject], length: u64) -> ptr[PyObject] {
    return shake_digest(receiver, length, False);
}

def _sha3_shake_128_hexdigest_impl(
    receiver: ptr[PyObject], length: u64
) -> ptr[PyObject] {
    return shake_digest(receiver, length, True);
}

def get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha3_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(i64(_Py_LibHacl_Hacl_Hash_SHA3_block_len(state.hash_state)));
}

def get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    index = type_index(Py_TYPE(instance));
    if index < 0 {
        object_error("SystemError", "bad argument to internal function");
        return NULL;
    }
    return PyUnicode_FromString(SHA3_TYPES[index][0]);
}

"""digest_size of a fixed-length SHA-3 object; SHAKE objects report 0."""
def get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha3_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(i64(_Py_LibHacl_Hacl_Hash_SHA3_hash_len(state.hash_state)));
}

def get_shake_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(0);
}

def get_capacity_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha3_of(instance);
    if state is None {
        return NULL;
    }
    rate = i64(_Py_LibHacl_Hacl_Hash_SHA3_block_len(state.hash_state)) * 8;
    return PyLong_FromLong(1600 - rate);
}

def get_rate_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha3_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(
        i64(_Py_LibHacl_Hacl_Hash_SHA3_block_len(state.hash_state)) * 8
    );
}

def get_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyBytes_FromStringAndSize(b"\x06", 1);
}

def get_shake_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyBytes_FromStringAndSize(b"\x1f", 1);
}
