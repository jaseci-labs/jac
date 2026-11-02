import from c {
    def _Py_LibHacl_Hacl_Streaming_HMAC_malloc_(
        hash_impl: u8, key: ptr, key_length: u32, dst: &mut ptr
    ) -> u8;  def _Py_LibHacl_Hacl_Streaming_HMAC_update(
        state: ptr, chunk: ptr, chunk_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Streaming_HMAC_digest(
        state: ptr, output: ptr, digest_length: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Streaming_HMAC_free(state: ptr);  def _Py_LibHacl_Hacl_Streaming_HMAC_copy(
        state: ptr
    ) -> ptr;  def _Py_LibHacl_Hacl_HMAC_compute_md5(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_sha1(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_sha2_224(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_sha2_256(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_sha2_384(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_sha2_512(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_sha3_224(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_sha3_256(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_sha3_384(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_sha3_512(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_blake2s_32(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );  def _Py_LibHacl_Hacl_HMAC_compute_blake2b_32(
        dst: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32
    );
}

glob HMAC_token = ClassToken();

glob UNKNOWN_HASH_ERROR: int = 0,
     HMAC_TYPE: int = 1;

glob:priv MAX_DIGEST_SIZE: i64 = 64,
     KIND_MD5: u8 = 0,
     KIND_SHA1: u8 = 1,
     KIND_SHA2_224: u8 = 2,
     KIND_SHA2_256: u8 = 3,
     KIND_SHA2_384: u8 = 4,
     KIND_SHA2_512: u8 = 5,
     KIND_SHA3_224: u8 = 6,
     KIND_SHA3_256: u8 = 7,
     KIND_SHA3_384: u8 = 8,
     KIND_SHA3_512: u8 = 9,
     KIND_BLAKE2S_32: u8 = 10,
     KIND_BLAKE2S_128: u8 = 11,
     KIND_BLAKE2B_32: u8 = 12,
     KIND_BLAKE2B_256: u8 = 13;

obj HashInfo {
    has name: str,
        hashlib_name: str,
        kind: u8,
        block_size: i64,
        digest_size: i64;

    def display_name -> str;
}

glob:priv HASH_INFO: list[HashInfo] = [
         HashInfo("md5", "", u8(0), 64, 16),
         HashInfo("sha1", "", u8(1), 64, 20),
         HashInfo("sha2_224", "sha224", u8(2), 64, 28),
         HashInfo("sha2_256", "sha256", u8(3), 64, 32),
         HashInfo("sha2_384", "sha384", u8(4), 128, 48),
         HashInfo("sha2_512", "sha512", u8(5), 128, 64),
         HashInfo("sha3_224", "", u8(6), 144, 28),
         HashInfo("sha3_256", "", u8(7), 136, 32),
         HashInfo("sha3_384", "", u8(8), 104, 48),
         HashInfo("sha3_512", "", u8(9), 72, 64),
         HashInfo("blake2s_32", "blake2s", u8(10), 64, 32),
         HashInfo("blake2b_32", "blake2b", u8(12), 128, 64)
     ];

obj HMACState(NativeState) {
    has lock: HashLock,
        hash_state: ptr = ptr(),
        name: str = "",
        kind: u8 = 0,
        block_size: i64 = 0,
        digest_size: i64 = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

def:priv convert_errno(code: u8) -> int;

def:priv narrow_kind(kind: u8) -> u8;

def:priv info_named(name: str) -> HashInfo | None;

def:priv find_hash_info(module: ptr[PyObject], ref: ptr[PyObject]) -> HashInfo | None;

def:priv hmac_update(hacl: ptr, address: ptr, size: i64);

def:priv hmac_of(instance: ptr[PyObject]) -> HMACState | None;

def _hmac_new_impl(
    module: ptr[PyObject],
    keyobj: ptr[PyObject],
    msgobj: ptr[PyObject],
    hash_info_ref: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_HMAC_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_update_impl(
    receiver: ptr[PyObject], msgobj: ptr[PyObject]
) -> ptr[PyObject];

def:priv hmac_digest(receiver: ptr[PyObject], as_hex: bool) -> ptr[PyObject];

def _hmac_HMAC_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_name_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_block_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_digest_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def hmac_repr(instance: ptr[PyObject]) -> ptr[PyObject];

def:priv compute(kind: u8, out: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32);

def:priv oneshot(
    kind: u8, digest_size: i64, keyobj: ptr[PyObject], msgobj: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_digest_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject], digest: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_md5_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha1_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha2_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha2_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha2_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha2_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha3_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha3_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha3_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha3_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_blake2s_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_blake2b_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

impl HashInfo.display_name -> str {
    return self.hashlib_name or self.name;
}

impl HMACState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl HMACState.clear {}

impl HMACState.drop {
    if self.hash_state {
        _Py_LibHacl_Hacl_Streaming_HMAC_free(self.hash_state);
    }
}

impl convert_errno(code: u8) -> int {
    if code == u8(0) {
        return 0;
    }
    if code == u8(1) {
        object_error(PyExc_ValueError, "invalid HACL* algorithm");
    } elif code == u8(2) {
        object_error(PyExc_ValueError, "invalid length");
    } elif code == u8(3) {
        object_error(PyExc_OverflowError, "maximum length exceeded");
    } elif code == u8(4) {
        PyErr_NoMemory();
    } else {
        object_error(
            PyExc_RuntimeError,
            f"HACL* internal routine failed with error code: {int(code)}"
        );
    }
    return -1;
}

impl narrow_kind(kind: u8) -> u8 {
    features = jacpy_hacl_simd_features();
    if kind == KIND_BLAKE2S_32 and (features & 1) != 0 {
        return KIND_BLAKE2S_128;
    }
    if kind == KIND_BLAKE2B_32 and (features & 3) == 3 {
        return KIND_BLAKE2B_256;
    }
    return kind;
}

impl info_named(name: str) -> HashInfo | None {
    for info in HASH_INFO {
        if info.name == name or (info.hashlib_name and info.hashlib_name == name) {
            return info;
        }
    }
    return None;
}

impl find_hash_info(module: ptr[PyObject], ref: ptr[PyObject]) -> HashInfo | None {
    if jacpy_is_unicode(ref) != 0 {
        if not PyUnicode_AsUTF8(ref) {
            return None;
        }
        found = info_named(text_value(ref));
        if found is not None {
            return found;
        }
        lower = PyObject_GetAttrString(ref, ptr[u8]("lower"));
        if not lower {
            return None;
        }
        lowered = PyObject_CallNoArgs(lower);
        jacpy_release(lower);
        if not lowered {
            return None;
        }
        if not PyUnicode_AsUTF8(lowered) {
            jacpy_release(lowered);
            return None;
        }
        found = info_named(text_value(lowered));
        jacpy_release(lowered);
        if found is not None {
            return found;
        }
    }
    shown = PyObject_Repr(ref);
    if not shown {
        return None;
    }
    prefix = PyUnicode_FromString(ptr[u8]("unsupported hash type: "));
    message = PyUnicode_Concat(prefix, shown) if prefix else NULL;
    jacpy_release(prefix);
    jacpy_release(shown);
    if message {
        PyErr_SetObject(jacpy_binding_state_get(module, UNKNOWN_HASH_ERROR), message);
        jacpy_release(message);
    }
    return None;
}

impl hmac_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Streaming_HMAC_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor += UINT32_MAX;
    }
    _Py_LibHacl_Hacl_Streaming_HMAC_update(hacl, cursor, u32(remaining));
}

impl hmac_of(instance: ptr[PyObject]) -> HMACState | None {
    state = hash_state_of(instance, HMAC_token);
    if isinstance(state, HMACState) {
        return state;
    }
    return None;
}

impl _hmac_new_impl(
    module: ptr[PyObject],
    keyobj: ptr[PyObject],
    msgobj: ptr[PyObject],
    hash_info_ref: ptr[PyObject]
) -> ptr[PyObject] {
    if not hash_info_ref {
        object_error(PyExc_TypeError, "new() missing 1 required argument 'digestmod'");
        return NULL;
    }
    info = find_hash_info(module, hash_info_ref);
    if info is None {
        return NULL;
    }
    key = hash_buffer(keyobj);
    if key is None {
        return NULL;
    }
    if key.size() > UINT32_MAX {
        key.close();
        object_error(PyExc_OverflowError, f"key length exceeds {UINT32_MAX}");
        return NULL;
    }
    kind = narrow_kind(info.kind);
    hacl = ptr();
    code = _Py_LibHacl_Hacl_Streaming_HMAC_malloc_(
        kind, key.address(), u32(key.size()), &mut hacl
    );
    key.close();
    if convert_errno(code) < 0 {
        return NULL;
    }
    state = HMACState(
        hash_state=hacl,
        lock=HashLock(),
        name=info.display_name(),
        kind=kind,
        block_size=info.block_size,
        digest_size=info.digest_size
    );
    instance = hash_object_new(
        jacpy_binding_state_get(module, HMAC_TYPE), HMAC_token, state
    );
    if not instance {
        return NULL;
    }
    if msgobj and msgobj != Py_None {
        if not hash_initial_data(hacl, msgobj, hmac_update) {
            jacpy_release(instance);
            return NULL;
        }
    }
    return instance;
}

impl _hmac_HMAC_copy_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    state.lock.enter();
    hacl = _Py_LibHacl_Hacl_Streaming_HMAC_copy(state.hash_state);
    state.lock.leave();
    if not hacl {
        PyErr_NoMemory();
        return NULL;
    }
    return hash_object_new(
        Py_TYPE(receiver),
        HMAC_token,
        HMACState(
            hash_state=hacl,
            lock=HashLock(),
            name=state.name,
            kind=state.kind,
            block_size=state.block_size,
            digest_size=state.digest_size
        )
    );
}

impl _hmac_HMAC_update_impl(
    receiver: ptr[PyObject], msgobj: ptr[PyObject]
) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_update(state.lock, state.hash_state, msgobj, hmac_update);
}

impl hmac_digest(receiver: ptr[PyObject], as_hex: bool) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    output = PyMem_Malloc(u64(MAX_DIGEST_SIZE));
    if not output {
        PyErr_NoMemory();
        return NULL;
    }
    state.lock.enter();
    code = _Py_LibHacl_Hacl_Streaming_HMAC_digest(
        state.hash_state, output, u32(state.digest_size)
    );
    state.lock.leave();
    result = NULL;
    if convert_errno(code) == 0 {
        result = _Py_strhex(output, state.digest_size)
            if as_hex
            else jacpy_bytes_from_memory(output, state.digest_size);
    }
    PyMem_Free(output);
    return result;
}

impl _hmac_HMAC_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return hmac_digest(receiver, False);
}

impl _hmac_HMAC_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return hmac_digest(receiver, True);
}

impl _hmac_HMAC_name_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return jacpy_unicode_from_text("hmac-" + state.name);
}

impl _hmac_HMAC_block_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(state.block_size);
}

impl _hmac_HMAC_digest_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(state.digest_size);
}

impl hmac_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(instance);
    if state is None {
        return NULL;
    }
    number = PyLong_FromVoidPtr(instance);
    if not number {
        return NULL;
    }
    address = PyNumber_ToBase(number, 16);
    jacpy_release(number);
    if not address {
        return NULL;
    }
    head = jacpy_unicode_from_text(f"<{state.name} HMAC object @ ");
    tail = PyUnicode_FromString(ptr[u8](">"));
    result = NULL;
    if head and tail {
        joined = PyUnicode_Concat(head, address);
        if joined {
            result = PyUnicode_Concat(joined, tail);
            jacpy_release(joined);
        }
    }
    jacpy_release(head);
    jacpy_release(tail);
    jacpy_release(address);
    return result;
}

impl compute(kind: u8, out: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32) {
    if kind == KIND_MD5 {
        _Py_LibHacl_Hacl_HMAC_compute_md5(out, key, key_len, data, data_len);
    } elif kind == KIND_SHA1 {
        _Py_LibHacl_Hacl_HMAC_compute_sha1(out, key, key_len, data, data_len);
    } elif kind == KIND_SHA2_224 {
        _Py_LibHacl_Hacl_HMAC_compute_sha2_224(out, key, key_len, data, data_len);
    } elif kind == KIND_SHA2_256 {
        _Py_LibHacl_Hacl_HMAC_compute_sha2_256(out, key, key_len, data, data_len);
    } elif kind == KIND_SHA2_384 {
        _Py_LibHacl_Hacl_HMAC_compute_sha2_384(out, key, key_len, data, data_len);
    } elif kind == KIND_SHA2_512 {
        _Py_LibHacl_Hacl_HMAC_compute_sha2_512(out, key, key_len, data, data_len);
    } elif kind == KIND_SHA3_224 {
        _Py_LibHacl_Hacl_HMAC_compute_sha3_224(out, key, key_len, data, data_len);
    } elif kind == KIND_SHA3_256 {
        _Py_LibHacl_Hacl_HMAC_compute_sha3_256(out, key, key_len, data, data_len);
    } elif kind == KIND_SHA3_384 {
        _Py_LibHacl_Hacl_HMAC_compute_sha3_384(out, key, key_len, data, data_len);
    } elif kind == KIND_SHA3_512 {
        _Py_LibHacl_Hacl_HMAC_compute_sha3_512(out, key, key_len, data, data_len);
    } elif kind == KIND_BLAKE2S_32 {
        _Py_LibHacl_Hacl_HMAC_compute_blake2s_32(out, key, key_len, data, data_len);
    } else {
        _Py_LibHacl_Hacl_HMAC_compute_blake2b_32(out, key, key_len, data, data_len);
    }
}

impl oneshot(
    kind: u8, digest_size: i64, keyobj: ptr[PyObject], msgobj: ptr[PyObject]
) -> ptr[PyObject] {
    key = hash_buffer(keyobj);
    if key is None {
        return NULL;
    }
    if key.size() > UINT32_MAX {
        key.close();
        object_error(PyExc_OverflowError, f"key length exceeds {UINT32_MAX}");
        return NULL;
    }
    msg = hash_buffer(msgobj);
    if msg is None {
        key.close();
        return NULL;
    }
    if msg.size() > UINT32_MAX {
        msg.close();
        key.close();
        object_error(PyExc_OverflowError, f"message length exceeds {UINT32_MAX}");
        return NULL;
    }
    out = PyMem_Malloc(u64(MAX_DIGEST_SIZE));
    if not out {
        msg.close();
        key.close();
        PyErr_NoMemory();
        return NULL;
    }
    compute(kind, out, key.address(), u32(key.size()), msg.address(), u32(msg.size()));
    msg.close();
    key.close();
    result = jacpy_bytes_from_memory(out, digest_size);
    PyMem_Free(out);
    return result;
}

impl _hmac_compute_digest_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject], digest: ptr[PyObject]
) -> ptr[PyObject] {
    info = find_hash_info(module, digest);
    if info is None {
        return NULL;
    }
    return oneshot(info.kind, info.digest_size, key, msg);
}

impl _hmac_compute_md5_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_MD5, 16, key, msg);
}

impl _hmac_compute_sha1_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA1, 20, key, msg);
}

impl _hmac_compute_sha2_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA2_224, 28, key, msg);
}

impl _hmac_compute_sha2_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA2_256, 32, key, msg);
}

impl _hmac_compute_sha2_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA2_384, 48, key, msg);
}

impl _hmac_compute_sha2_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA2_512, 64, key, msg);
}

impl _hmac_compute_sha3_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA3_224, 28, key, msg);
}

impl _hmac_compute_sha3_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA3_256, 32, key, msg);
}

impl _hmac_compute_sha3_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA3_384, 48, key, msg);
}

impl _hmac_compute_sha3_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA3_512, 64, key, msg);
}

impl _hmac_compute_blake2s_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_BLAKE2S_32, 32, key, msg);
}

impl _hmac_compute_blake2b_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_BLAKE2B_32, 64, key, msg);
}
