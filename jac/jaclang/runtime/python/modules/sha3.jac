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

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

def:priv sha3_update(hacl: ptr, address: ptr, size: i64);

def:priv sha3_digest(hacl: ptr, output: ptr) -> i64;

def:priv sha3_of(instance: ptr[PyObject]) -> SHA3State | None;

def:priv type_index(cls: ptr[PyObject]) -> int;

def:priv new_sha3_object(cls: ptr[PyObject], hacl: ptr) -> ptr[PyObject];

def py_sha3_new_impl(
    type: ptr[PyObject],
    data_obj: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _sha3_sha3_224_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _sha3_sha3_224_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _sha3_sha3_224_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _sha3_sha3_224_update_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject];

def:priv shake_digest(
    receiver: ptr[PyObject], length: u64, as_hex: bool
) -> ptr[PyObject];

def _sha3_shake_128_digest_impl(receiver: ptr[PyObject], length: u64) -> ptr[PyObject];

def _sha3_shake_128_hexdigest_impl(
    receiver: ptr[PyObject], length: u64
) -> ptr[PyObject];

def get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_shake_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_capacity_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_rate_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_shake_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

impl SHA3State.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl SHA3State.clear {}

impl SHA3State.drop {
    if self.hash_state {
        _Py_LibHacl_Hacl_Hash_SHA3_free(self.hash_state);
    }
}

impl sha3_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_SHA3_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor += UINT32_MAX;
    }
    _Py_LibHacl_Hacl_Hash_SHA3_update(hacl, cursor, u32(remaining));
}

impl sha3_digest(hacl: ptr, output: ptr) -> i64 {
    _Py_LibHacl_Hacl_Hash_SHA3_digest(hacl, output);
    return i64(_Py_LibHacl_Hacl_Hash_SHA3_hash_len(hacl));
}

impl sha3_of(instance: ptr[PyObject]) -> SHA3State | None {
    state = hash_state_of(instance, SHA3_token);
    if isinstance(state, SHA3State) {
        return state;
    }
    return None;
}

impl type_index(cls: ptr[PyObject]) -> int {
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

impl new_sha3_object(cls: ptr[PyObject], hacl: ptr) -> ptr[PyObject] {
    if not hacl {
        PyErr_NoMemory();
        return NULL;
    }
    return hash_object_new(
        cls, SHA3_token, SHA3State(hash_state=hacl, lock=HashLock())
    );
}

impl py_sha3_new_impl(
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
        object_error(PyExc_SystemError, "bad argument to internal function");
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

impl _sha3_sha3_224_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    state.lock.enter();
    hacl = _Py_LibHacl_Hacl_Hash_SHA3_copy(state.hash_state);
    state.lock.leave();
    return new_sha3_object(Py_TYPE(receiver), hacl);
}

impl _sha3_sha3_224_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_digest(
        state.lock, state.hash_state, SHA3_MAX_DIGESTSIZE, -1, sha3_digest, False
    );
}

impl _sha3_sha3_224_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_digest(
        state.lock, state.hash_state, SHA3_MAX_DIGESTSIZE, -1, sha3_digest, True
    );
}

impl _sha3_sha3_224_update_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_update(state.lock, state.hash_state, data, sha3_update);
}

impl shake_digest(receiver: ptr[PyObject], length: u64, as_hex: bool) -> ptr[PyObject] {
    state = sha3_of(receiver);
    if state is None {
        return NULL;
    }
    if length >= u64(1 << 29) {
        object_error(PyExc_ValueError, "length is too large");
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

impl _sha3_shake_128_digest_impl(
    receiver: ptr[PyObject], length: u64
) -> ptr[PyObject] {
    return shake_digest(receiver, length, False);
}

impl _sha3_shake_128_hexdigest_impl(
    receiver: ptr[PyObject], length: u64
) -> ptr[PyObject] {
    return shake_digest(receiver, length, True);
}

impl get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha3_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(i64(_Py_LibHacl_Hacl_Hash_SHA3_block_len(state.hash_state)));
}

impl get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    index = type_index(Py_TYPE(instance));
    if index < 0 {
        object_error(PyExc_SystemError, "bad argument to internal function");
        return NULL;
    }
    return jacpy_unicode_from_text(SHA3_TYPES[index][0]);
}

impl get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha3_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(i64(_Py_LibHacl_Hacl_Hash_SHA3_hash_len(state.hash_state)));
}

impl get_shake_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(0);
}

impl get_capacity_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha3_of(instance);
    if state is None {
        return NULL;
    }
    rate = i64(_Py_LibHacl_Hacl_Hash_SHA3_block_len(state.hash_state)) * 8;
    return PyLong_FromLong(1600 - rate);
}

impl get_rate_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha3_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(
        i64(_Py_LibHacl_Hacl_Hash_SHA3_block_len(state.hash_state)) * 8
    );
}

impl get_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyBytes_FromStringAndSize(ptr[u8]("\x06"), 1);
}

impl get_shake_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyBytes_FromStringAndSize(ptr[u8]("\x1f"), 1);
}
