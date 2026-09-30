"""HMAC over HACL*; derived from CPython 3.14.6 Modules/hmacmodule.c.

See ../LICENSE.cpython. The HACL* library stays C: CPython's
Modules/_hacl/libHacl_HMAC.a, which the registry links for _hmac. Only hash
functions named in HASH_INFO are recognized. A BLAKE2 HMAC object uses the
vectorized HACL* kind when the CPU runs it, decided once at creation.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_NoMemory,
    PyErr_SetObject,
    PyLong_FromLong,
    PyLong_FromVoidPtr,
    PyMem_Free,
    PyMem_Malloc,
    PyNumber_ToBase,
    PyObject,
    PyObject_CallNoArgs,
    PyObject_GetAttrString,
    PyObject_Repr,
    PyUnicode_AsUTF8,
    PyUnicode_Concat,
    PyUnicode_FromString,
    Py_TYPE,
    _Py_strhex,
    jacpy_bytes_from_memory,
    jacpy_hacl_simd_features,
    jacpy_is_none,
    jacpy_is_unicode,
    jacpy_offset,
    jacpy_release
}
import from jaclang.runtime.python.capi { object_error, text_value }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.modules.hashlib {
    HashLock,
    UINT32_MAX,
    hash_buffer,
    hash_initial_data,
    hash_object_new,
    hash_state_of,
    hash_update
}
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

"""py_hmac_static_hinfo: HACL* name, hashlib name ("" when it is the same),
static kind, block size and digest size. Both names find an entry; the
hashlib name is the one objects display."""
obj HashInfo {
    has name: str,
        hashlib_name: str,
        kind: u8,
        block_size: i64,
        digest_size: i64;

    def display_name -> str {
        return self.hashlib_name or self.name;
    }
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

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        if self.hash_state {
            _Py_LibHacl_Hacl_Streaming_HMAC_free(self.hash_state);
        }
    }
}

"""_hacl_convert_errno(): 0 for success, else -1 with the error set."""
def:priv convert_errno(code: u8) -> int {
    if code == u8(0) {
        return 0;
    }
    if code == u8(1) {
        object_error("ValueError", "invalid HACL* algorithm");
    } elif code == u8(2) {
        object_error("ValueError", "invalid length");
    } elif code == u8(3) {
        object_error("OverflowError", "maximum length exceeded");
    } elif code == u8(4) {
        PyErr_NoMemory();
    } else {
        object_error(
            "RuntimeError",
            f"HACL* internal routine failed with error code: {int(code)}"
        );
    }
    return -1;
}

"""narrow_hmac_hash_kind(): the vectorized BLAKE2 kind when the CPU runs it."""
def:priv narrow_kind(kind: u8) -> u8 {
    features = jacpy_hacl_simd_features();
    if kind == KIND_BLAKE2S_32 and (features & 1) != 0 {
        return KIND_BLAKE2S_128;
    }
    if kind == KIND_BLAKE2B_32 and (features & 3) == 3 {
        return KIND_BLAKE2B_256;
    }
    return kind;
}

def:priv info_named(name: str) -> HashInfo | None {
    for info in HASH_INFO {
        if info.name == name or (info.hashlib_name and info.hashlib_name == name) {
            return info;
        }
    }
    return None;
}

"""find_hash_info(): the entry for a hash name, looked up as given and then
lowercased; None with UnknownHashError (or the lookup's error) set."""
def:priv find_hash_info(module: ptr[PyObject], ref: ptr[PyObject]) -> HashInfo | None {
    if jacpy_is_unicode(ref) != 0 {
        if not PyUnicode_AsUTF8(ref) {
            return None;
        }
        found = info_named(text_value(ref));
        if found is not None {
            return found;
        }
        lower = PyObject_GetAttrString(ref, "lower");
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
    prefix = PyUnicode_FromString("unsupported hash type: ");
    message = PyUnicode_Concat(prefix, shown) if prefix else NULL;
    jacpy_release(prefix);
    jacpy_release(shown);
    if message {
        PyErr_SetObject(jacpy_binding_state_get(module, UNKNOWN_HASH_ERROR), message);
        jacpy_release(message);
    }
    return None;
}

"""Py_HMAC_HACL_UPDATE in a release build: the error code is not checked."""
def:priv hmac_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Streaming_HMAC_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor = jacpy_offset(cursor, UINT32_MAX);
    }
    _Py_LibHacl_Hacl_Streaming_HMAC_update(hacl, cursor, u32(remaining));
}

def:priv hmac_of(instance: ptr[PyObject]) -> HMACState | None {
    state = hash_state_of(instance, HMAC_token);
    if isinstance(state, HMACState) {
        return state;
    }
    return None;
}

def _hmac_new_impl(
    module: ptr[PyObject],
    keyobj: ptr[PyObject],
    msgobj: ptr[PyObject],
    hash_info_ref: ptr[PyObject]
) -> ptr[PyObject] {
    if not hash_info_ref {
        object_error("TypeError", "new() missing 1 required argument 'digestmod'");
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
        object_error("OverflowError", f"key length exceeds {UINT32_MAX}");
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
    if msgobj and jacpy_is_none(msgobj) == 0 {
        if not hash_initial_data(hacl, msgobj, hmac_update) {
            jacpy_release(instance);
            return NULL;
        }
    }
    return instance;
}

def _hmac_HMAC_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
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

def _hmac_HMAC_update_impl(
    receiver: ptr[PyObject], msgobj: ptr[PyObject]
) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return hash_update(state.lock, state.hash_state, msgobj, hmac_update);
}

"""hmac_digest_compute_cond_lock(), as bytes or hex text."""
def:priv hmac_digest(receiver: ptr[PyObject], as_hex: bool) -> ptr[PyObject] {
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

def _hmac_HMAC_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return hmac_digest(receiver, False);
}

def _hmac_HMAC_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return hmac_digest(receiver, True);
}

def _hmac_HMAC_name_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return PyUnicode_FromString("hmac-" + state.name);
}

def _hmac_HMAC_block_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(state.block_size);
}

def _hmac_HMAC_digest_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(state.digest_size);
}

"""HMACObject_repr(): "<name HMAC object @ address>", the address as %p
renders it."""
def hmac_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
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
    head = PyUnicode_FromString(f"<{state.name} HMAC object @ ");
    tail = PyUnicode_FromString(">");
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

"""The one-shot HACL* HMAC of a kind: out receives the digest."""
def:priv compute(kind: u8, out: ptr, key: ptr, key_len: u32, data: ptr, data_len: u32) {
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

"""Py_HMAC_HACL_ONESHOT: key and message longer than 4 GiB raise
OverflowError; the hmac module falls back to OpenSSL for those."""
def:priv oneshot(
    kind: u8, digest_size: i64, keyobj: ptr[PyObject], msgobj: ptr[PyObject]
) -> ptr[PyObject] {
    key = hash_buffer(keyobj);
    if key is None {
        return NULL;
    }
    if key.size() > UINT32_MAX {
        key.close();
        object_error("OverflowError", f"key length exceeds {UINT32_MAX}");
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
        object_error("OverflowError", f"message length exceeds {UINT32_MAX}");
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

def _hmac_compute_digest_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject], digest: ptr[PyObject]
) -> ptr[PyObject] {
    info = find_hash_info(module, digest);
    if info is None {
        return NULL;
    }
    return oneshot(info.kind, info.digest_size, key, msg);
}

def _hmac_compute_md5_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_MD5, 16, key, msg);
}

def _hmac_compute_sha1_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA1, 20, key, msg);
}

def _hmac_compute_sha2_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA2_224, 28, key, msg);
}

def _hmac_compute_sha2_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA2_256, 32, key, msg);
}

def _hmac_compute_sha2_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA2_384, 48, key, msg);
}

def _hmac_compute_sha2_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA2_512, 64, key, msg);
}

def _hmac_compute_sha3_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA3_224, 28, key, msg);
}

def _hmac_compute_sha3_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA3_256, 32, key, msg);
}

def _hmac_compute_sha3_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA3_384, 48, key, msg);
}

def _hmac_compute_sha3_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_SHA3_512, 64, key, msg);
}

def _hmac_compute_blake2s_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_BLAKE2S_32, 32, key, msg);
}

def _hmac_compute_blake2b_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot(KIND_BLAKE2B_32, 64, key, msg);
}
