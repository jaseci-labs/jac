glob HASH_token = ClassToken(),
     HMAC_token = ClassToken();

glob MUNCH_SIZE: i64 = 2147483647,
     INT_MAX: i64 = 2147483647,
     STATE_EVP_TYPE: int = 0,
     STATE_EVPXOF_TYPE: int = 1,
     STATE_HMAC_TYPE: int = 2,
     STATE_CONSTRUCTS: int = 3,
     STATE_UNSUPPORTED_DIGESTMOD_ERROR: int = 4,
     STATE_COUNT: int = 5;

glob PY_HT_EVP: int = 0,
     PY_HT_EVP_NOSECURITY: int = 1,
     PY_HT_MAC: int = 2,
     PY_HT_PBKDF2: int = 3;

glob:priv NON_FIPS_PROPERTIES: ptr[u8] = c_string_copy("-fips");

def:priv hash_entries -> list[tuple[str, str, str, i64]];

glob:priv PY_HASHES: list[tuple[str, str, str, i64]] = hash_entries();

obj HashEntry {
    has py_name: str,
        ossl_name: str,
        ossl_nid: i64,
        evp: ptr = ptr(),
        evp_nosecurity: ptr = ptr();

    def release;
}

obj HashlibState(NativeState) {
    has table: dict[str, HashEntry] = {},
        entries: list[HashEntry] = [];

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

def hashlib_state_new -> HashlibState;

def:priv hashlib_state(module: ptr[PyObject]) -> HashlibState | None;

def state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject];

def:priv set_ssl_exception_from_errcode(exc: ptr[PyObject], errcode: u64);

def:priv raise_ssl_error(exc: ptr[PyObject], fallback: str);

def:priv notify_ssl_error_occurred;

def:priv py_digest_name(md: ptr) -> ptr[PyObject];

def:priv py_digest_by_name(module: ptr[PyObject], name: str, py_ht: int) -> ptr;

def:priv py_digest_by_digestmod(
    module: ptr[PyObject], digestmod: ptr[PyObject], py_ht: int
) -> ptr;

obj EVPState(NativeState) {
    has lock: HashLock,
        ctx: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

def:priv evp_of(instance: ptr[PyObject]) -> EVPState | None;

def:priv new_evp_object(type: ptr[PyObject]) -> ptr[PyObject];

def:priv evp_hash(ctx: ptr, address: ptr, size: i64) -> bool;

def:priv locked_evp_copy(target: ptr, state: EVPState) -> bool;

def EVP_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def:priv evp_final(receiver: ptr[PyObject], as_hex: bool) -> ptr[PyObject];

def EVP_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def EVP_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def EVP_update_impl(receiver: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def evp_block_size(instance: ptr[PyObject]) -> ptr[PyObject];

def evp_digest_size(instance: ptr[PyObject]) -> ptr[PyObject];

def evp_name(instance: ptr[PyObject]) -> ptr[PyObject];

def evp_repr(instance: ptr[PyObject]) -> ptr[PyObject];

def:priv evpxof_final(
    receiver: ptr[PyObject], length: i64, as_hex: bool
) -> ptr[PyObject];

def EVPXOF_digest_impl(receiver: ptr[PyObject], length: i64) -> ptr[PyObject];

def EVPXOF_hexdigest_impl(receiver: ptr[PyObject], length: i64) -> ptr[PyObject];

def:priv new_hash(
    module: ptr[PyObject],
    digestname: str,
    data_obj: ptr[PyObject],
    usedforsecurity: bool
) -> ptr[PyObject];

def:priv call_hashlib_new(
    module: ptr[PyObject],
    name: str,
    data: ptr[PyObject],
    string: ptr[PyObject],
    usedforsecurity: bool
) -> ptr[PyObject];

def _hashlib_new_impl(
    module: ptr[PyObject],
    name: str,
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_md5_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_sha1_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_sha224_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_sha256_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_sha384_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_sha512_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_sha3_224_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_sha3_256_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_sha3_384_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_sha3_512_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_shake_128_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_openssl_shake_256_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def pbkdf2_hmac_impl(
    module: ptr[PyObject],
    hash_name: str,
    password: BufferArgument,
    salt: BufferArgument,
    iterations: i64,
    dklen_obj: ptr[PyObject]
) -> ptr[PyObject];

def _hashlib_scrypt_impl(
    module: ptr[PyObject],
    password: BufferArgument,
    salt: BufferArgument,
    n: u64,
    r: u64,
    p: u64,
    maxmem: i64,
    dklen: i64
) -> ptr[PyObject];

def _hashlib_hmac_singleshot_impl(
    module: ptr[PyObject],
    key: BufferArgument,
    msg: BufferArgument,
    digest: ptr[PyObject]
) -> ptr[PyObject];

obj HMACState(NativeState) {
    has lock: HashLock,
        ctx: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

def:priv hmac_of(instance: ptr[PyObject]) -> HMACState | None;

def:priv hmac_update(state: HMACState, obj_: ptr[PyObject]) -> bool;

def _hashlib_hmac_new_impl(
    module: ptr[PyObject],
    key: BufferArgument,
    msg_obj: ptr[PyObject],
    digestmod: ptr[PyObject]
) -> ptr[PyObject];

def:priv locked_hmac_copy(target: ptr, state: HMACState) -> bool;

def:priv hmac_md(state: HMACState) -> ptr;

def:priv hmac_digest_size(state: HMACState) -> i64;

def _hashlib_HMAC_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hashlib_HMAC_update_impl(
    receiver: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def:priv hmac_final(state: HMACState, as_hex: bool) -> ptr[PyObject];

def _hashlib_HMAC_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hashlib_HMAC_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def hmac_get_digest_size(instance: ptr[PyObject]) -> ptr[PyObject];

def hmac_get_block_size(instance: ptr[PyObject]) -> ptr[PyObject];

def hmac_get_name(instance: ptr[PyObject]) -> ptr[PyObject];

def hmac_repr(instance: ptr[PyObject]) -> ptr[PyObject];

def _hashlib_get_fips_mode_impl(module: ptr[PyObject]) -> i32;

def _hashlib_compare_digest_impl(
    module: ptr[PyObject], a: ptr[PyObject], b: ptr[PyObject]
) -> ptr[PyObject];

obj NameMapperState {
    has names: ptr[PyObject] = NULL,
        error: bool = False;
}

glob:priv name_mapper_state = NameMapperState();

def:priv openssl_hash_name_mapper(md: ptr, argument: ptr);

def hashlib_md_meth_names(module: ptr[PyObject]) -> bool;

def hashlib_init_constructors(
    module: ptr[PyObject], methods: list[MethodDefinition]
) -> ptr[PyObject];

def hashlib_exception -> ptr[PyObject];

def dict_proxy(mapping: ptr[PyObject]) -> ptr[PyObject];

def add_object(module: ptr[PyObject], name: str, value: ptr[PyObject]) -> bool;

impl hash_entries -> list[tuple[str, str, str, i64]] {
    candidates: list[tuple[str, str, str, i64, str]] = [
        ("md5", "MD5", SN_md5, NID_md5, "NID_md5"),
        ("sha1", "SHA1", SN_sha1, NID_sha1, "NID_sha1"),
        ("sha224", "SHA224", SN_sha224, NID_sha224, "NID_sha224"),
        ("sha256", "SHA256", SN_sha256, NID_sha256, "NID_sha256"),
        ("sha384", "SHA384", SN_sha384, NID_sha384, "NID_sha384"),
        ("sha512", "SHA512", SN_sha512, NID_sha512, "NID_sha512"),
        ("sha512_224", "SHA512_224", SN_sha512_224, NID_sha512_224, "NID_sha512_224"),
        ("sha512_256", "SHA512_256", SN_sha512_256, NID_sha512_256, "NID_sha512_256"),
        ("sha3_224", "", SN_sha3_224, NID_sha3_224, "NID_sha3_224"),
        ("sha3_256", "", SN_sha3_256, NID_sha3_256, "NID_sha3_256"),
        ("sha3_384", "", SN_sha3_384, NID_sha3_384, "NID_sha3_384"),
        ("sha3_512", "", SN_sha3_512, NID_sha3_512, "NID_sha3_512"),
        ("shake_128", "", SN_shake128, NID_shake128, "NID_shake128"),
        ("shake_256", "", SN_shake256, NID_shake256, "NID_shake256"),
        ("blake2s", "blake2s256", SN_blake2s256, NID_blake2s256, "NID_blake2s256"),
        ("blake2b", "blake2b512", SN_blake2b512, NID_blake2b512, "NID_blake2b512")
    ];
    entries: list[tuple[str, str, str, i64]] = [];
    for (py_name, alias, ossl_name, nid, macro) in candidates {
        if macro not in UNDEFINED {
            entries.append((py_name, alias, ossl_name, nid));
        }
    }
    return entries;
}

impl HashEntry.release {
    if self.evp {
        EVP_MD_free(self.evp);
        self.evp = ptr();
    }
    if self.evp_nosecurity {
        EVP_MD_free(self.evp_nosecurity);
        self.evp_nosecurity = ptr();
    }
}

impl HashlibState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl HashlibState.clear {
    for hash_entry in self.entries {
        hash_entry.release();
    }
    self.entries = [];
    self.table = {};
}

impl HashlibState.drop {
    self.clear();
}

impl hashlib_state_new -> HashlibState {
    state = HashlibState();
    for (py_name, alias, ossl_name, nid) in PY_HASHES {
        hash_entry = HashEntry(py_name=py_name, ossl_name=ossl_name, ossl_nid=nid);
        state.entries.append(hash_entry);
        state.table[py_name] = hash_entry;
        if alias {
            state.table[alias] = hash_entry;
        }
    }
    return state;
}

impl hashlib_state(module: ptr[PyObject]) -> HashlibState | None {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, HashlibState) {
            return state;
        }
    }
    return None;
}

impl state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

impl set_ssl_exception_from_errcode(exc: ptr[PyObject], errcode: u64) {
    lib = ERR_lib_error_string(errcode);
    func = ERR_func_error_string(errcode);
    reason = ERR_reason_error_string(errcode);
    if lib and func {
        PyErr_Format(exc, "[%s: %s] %s", lib, func, reason);
    } elif lib {
        PyErr_Format(exc, "[%s] %s", lib, reason);
    } else {
        PyErr_Format(exc, "%s", reason);
    }
}

impl raise_ssl_error(exc: ptr[PyObject], fallback: str) {
    errcode = ERR_peek_last_error();
    if errcode {
        ERR_clear_error();
        set_ssl_exception_from_errcode(exc, errcode);
    } else {
        object_error(exc, fallback);
    }
}

impl notify_ssl_error_occurred {
    raise_ssl_error(PyExc_ValueError, "no reason supplied");
}

impl py_digest_name(md: ptr) -> ptr[PyObject] {
    nid = i64(EVP_MD_get_type(md));
    for (py_name, _, _, ossl_nid) in PY_HASHES {
        if ossl_nid == nid {
            return jacpy_unicode_from_text(py_name);
        }
    }
    name = OBJ_nid2ln(i32(nid));
    if not name {
        name = OBJ_nid2sn(i32(nid));
    }
    return c_string_text(name);
}

impl py_digest_by_name(module: ptr[PyObject], name: str, py_ht: int) -> ptr {
    digest = ptr();
    state = hashlib_state(module);
    hash_entry = state.table.get(name) if state is not None else None;
    properties = NON_FIPS_PROPERTIES if py_ht == PY_HT_EVP_NOSECURITY else ptr[u8]();
    if hash_entry is not None {
        if py_ht == PY_HT_EVP_NOSECURITY {
            digest = hash_entry.evp_nosecurity;
            if not digest {
                digest = EVP_MD_fetch(ptr(), hash_entry.ossl_name, properties);
                hash_entry.evp_nosecurity = digest;
            }
        } else {
            digest = hash_entry.evp;
            if not digest {
                digest = EVP_MD_fetch(ptr(), hash_entry.ossl_name, properties);
                hash_entry.evp = digest;
            }
        }
        if digest {
            EVP_MD_up_ref(digest);
        }
    } else {
        digest = EVP_MD_fetch(ptr(), name, properties);
    }
    if not digest {
        raise_ssl_error(
            state_ref(module, STATE_UNSUPPORTED_DIGESTMOD_ERROR),
            f"unsupported hash type {name}"
        );
        return ptr();
    }
    return digest;
}

impl py_digest_by_digestmod(
    module: ptr[PyObject], digestmod: ptr[PyObject], py_ht: int
) -> ptr {
    name_obj = NULL;
    if jacpy_is_unicode(digestmod) != 0 {
        name_obj = digestmod;
    } else {
        name_obj = PyDict_GetItemWithError(
            state_ref(module, STATE_CONSTRUCTS), digestmod
        );
    }
    if not name_obj {
        if not PyErr_Occurred() {
            PyErr_Format(
                state_ref(module, STATE_UNSUPPORTED_DIGESTMOD_ERROR),
                "Unsupported digestmod %R",
                digestmod
            );
        }
        return ptr();
    }
    if not PyUnicode_AsUTF8(name_obj) {
        return ptr();
    }
    return py_digest_by_name(module, text_value(name_obj), py_ht);
}

impl EVPState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl EVPState.clear {}

impl EVPState.drop {
    if self.ctx {
        EVP_MD_CTX_free(self.ctx);
    }
}

impl evp_of(instance: ptr[PyObject]) -> EVPState | None {
    state = hash_state_of(instance, HASH_token);
    if isinstance(state, EVPState) {
        return state;
    }
    return None;
}

impl new_evp_object(type: ptr[PyObject]) -> ptr[PyObject] {
    ctx = EVP_MD_CTX_new();
    if not ctx {
        PyErr_NoMemory();
        return NULL;
    }
    return hash_object_new(type, HASH_token, EVPState(lock=HashLock(), ctx=ctx));
}

impl evp_hash(ctx: ptr, address: ptr, size: i64) -> bool {
    remaining = size;
    cursor = address;
    while 0 < remaining {
        process = MUNCH_SIZE if remaining > MUNCH_SIZE else remaining;
        if EVP_DigestUpdate(ctx, cursor, u64(process)) == 0 {
            return False;
        }
        remaining -= process;
        cursor += process;
    }
    return True;
}

impl locked_evp_copy(target: ptr, state: EVPState) -> bool {
    state.lock.enter();
    result = EVP_MD_CTX_copy(target, state.ctx);
    state.lock.leave();
    return result != 0;
}

impl EVP_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = evp_of(receiver);
    if state is None {
        return NULL;
    }
    copy = new_evp_object(Py_TYPE(receiver));
    if not copy {
        return NULL;
    }
    target = evp_of(copy);
    if target is None or not locked_evp_copy(target.ctx, state) {
        jacpy_release(copy);
        notify_ssl_error_occurred();
        return NULL;
    }
    return copy;
}

impl evp_final(receiver: ptr[PyObject], as_hex: bool) -> ptr[PyObject] {
    state = evp_of(receiver);
    if state is None {
        return NULL;
    }
    temp_ctx = EVP_MD_CTX_new();
    if not temp_ctx {
        PyErr_NoMemory();
        return NULL;
    }
    digest = PyMem_Malloc(u64(EVP_MAX_MD_SIZE));
    if not digest {
        EVP_MD_CTX_free(temp_ctx);
        PyErr_NoMemory();
        return NULL;
    }
    if not locked_evp_copy(temp_ctx, state) {
        PyMem_Free(digest);
        EVP_MD_CTX_free(temp_ctx);
        notify_ssl_error_occurred();
        return NULL;
    }
    digest_size = i64(EVP_MD_CTX_get_size_ex(temp_ctx));
    if EVP_DigestFinal(temp_ctx, digest, ptr()) == 0 {
        PyMem_Free(digest);
        EVP_MD_CTX_free(temp_ctx);
        notify_ssl_error_occurred();
        return NULL;
    }
    EVP_MD_CTX_free(temp_ctx);
    result = _Py_strhex(digest, digest_size)
        if as_hex
        else jacpy_bytes_from_memory(digest, digest_size);
    PyMem_Free(digest);
    return result;
}

impl EVP_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return evp_final(receiver, False);
}

impl EVP_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return evp_final(receiver, True);
}

impl EVP_update_impl(receiver: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    state = evp_of(receiver);
    if state is None {
        return NULL;
    }
    view = hash_buffer(obj_);
    if view is None {
        return NULL;
    }
    address = view.address();
    size = view.size();
    if not state.lock.use_mutex
        and size >= HASHLIB_GIL_MINSIZE
        and not state.lock.enable() {
        view.close();
        return NULL;
    }
    result = False;
    if state.lock.use_mutex {
        ctx = state.ctx;
        mutex = state.lock.lock;
        thread = PyEval_SaveThread();
        PyThread_acquire_lock(mutex, 1);
        result = evp_hash(ctx, address, size);
        PyThread_release_lock(mutex);
        PyEval_RestoreThread(thread);
    } else {
        result = evp_hash(state.ctx, address, size);
    }
    view.close();
    if not result {
        notify_ssl_error_occurred();
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

impl evp_block_size(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = evp_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(i64(EVP_MD_get_block_size(EVP_MD_CTX_get0_md(state.ctx))));
}

impl evp_digest_size(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = evp_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(i64(EVP_MD_CTX_get_size_ex(state.ctx)));
}

impl evp_name(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = evp_of(instance);
    if state is None {
        return NULL;
    }
    md = EVP_MD_CTX_get0_md(state.ctx);
    if not md {
        notify_ssl_error_occurred();
        return NULL;
    }
    return py_digest_name(md);
}

impl evp_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    name = evp_name(instance);
    if not name {
        return NULL;
    }
    result = PyUnicode_FromFormat("<%U %T object @ %p>", name, instance, instance);
    jacpy_release(name);
    return result;
}

impl evpxof_final(receiver: ptr[PyObject], length: i64, as_hex: bool) -> ptr[PyObject] {
    state = evp_of(receiver);
    if state is None {
        return NULL;
    }
    retval = NULL;
    digest = ptr();
    if as_hex {
        digest = PyMem_Malloc(c_size(length));
        if not digest {
            PyErr_NoMemory();
            return NULL;
        }
    } else {
        retval = jacpy_bytes_from_memory(ptr(), length);
        if not retval {
            return NULL;
        }
        digest = jacpy_bytes_address(retval);
    }
    temp_ctx = EVP_MD_CTX_new();
    if not temp_ctx {
        if as_hex {
            PyMem_Free(digest);
        } else {
            jacpy_release(retval);
        }
        PyErr_NoMemory();
        return NULL;
    }
    if not locked_evp_copy(temp_ctx, state)
        or EVP_DigestFinalXOF(temp_ctx, digest, c_size(length)) == 0 {
        if as_hex {
            PyMem_Free(digest);
        } else {
            jacpy_release(retval);
        }
        EVP_MD_CTX_free(temp_ctx);
        notify_ssl_error_occurred();
        return NULL;
    }
    EVP_MD_CTX_free(temp_ctx);
    if as_hex {
        retval = _Py_strhex(digest, length);
        PyMem_Free(digest);
    }
    return retval;
}

impl EVPXOF_digest_impl(receiver: ptr[PyObject], length: i64) -> ptr[PyObject] {
    return evpxof_final(receiver, length, False);
}

impl EVPXOF_hexdigest_impl(receiver: ptr[PyObject], length: i64) -> ptr[PyObject] {
    return evpxof_final(receiver, length, True);
}

impl new_hash(
    module: ptr[PyObject],
    digestname: str,
    data_obj: ptr[PyObject],
    usedforsecurity: bool
) -> ptr[PyObject] {
    view: BufferArgument | None = None;
    if data_obj {
        view = hash_buffer(data_obj);
        if view is None {
            return NULL;
        }
    }
    digest = py_digest_by_name(
        module, digestname, PY_HT_EVP if usedforsecurity else PY_HT_EVP_NOSECURITY
    );
    if not digest {
        if view is not None {
            view.close();
        }
        return NULL;
    }
    type = state_ref(module, STATE_EVP_TYPE);
    if (EVP_MD_get_flags(digest) & u64(EVP_MD_FLAG_XOF)) == u64(EVP_MD_FLAG_XOF) {
        type = state_ref(module, STATE_EVPXOF_TYPE);
    }
    instance = new_evp_object(type);
    if instance {
        state = evp_of(instance);
        if state is None or EVP_DigestInit_ex(state.ctx, digest, ptr()) == 0 {
            notify_ssl_error_occurred();
            jacpy_release(instance);
            instance = NULL;
        } elif view is not None and view.address() and view.size() {
            address = view.address();
            size = view.size();
            result = False;
            if size >= HASHLIB_GIL_MINSIZE {
                ctx = state.ctx;
                thread = PyEval_SaveThread();
                result = evp_hash(ctx, address, size);
                PyEval_RestoreThread(thread);
            } else {
                result = evp_hash(state.ctx, address, size);
            }
            if not result {
                notify_ssl_error_occurred();
                jacpy_release(instance);
                instance = NULL;
            }
        }
    }
    if view is not None {
        view.close();
    }
    EVP_MD_free(digest);
    return instance;
}

impl call_hashlib_new(
    module: ptr[PyObject],
    name: str,
    data: ptr[PyObject],
    string: ptr[PyObject],
    usedforsecurity: bool
) -> ptr[PyObject] {
    (status, data_obj) = data_argument(data, string);
    if status < 0 {
        return NULL;
    }
    return new_hash(module, name, data_obj, usedforsecurity);
}

impl _hashlib_new_impl(
    module: ptr[PyObject],
    name: str,
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, name, data, string, usedforsecurity);
}

impl _hashlib_openssl_md5_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "md5", data, string, usedforsecurity);
}

impl _hashlib_openssl_sha1_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "sha1", data, string, usedforsecurity);
}

impl _hashlib_openssl_sha224_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "sha224", data, string, usedforsecurity);
}

impl _hashlib_openssl_sha256_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "sha256", data, string, usedforsecurity);
}

impl _hashlib_openssl_sha384_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "sha384", data, string, usedforsecurity);
}

impl _hashlib_openssl_sha512_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "sha512", data, string, usedforsecurity);
}

impl _hashlib_openssl_sha3_224_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "sha3_224", data, string, usedforsecurity);
}

impl _hashlib_openssl_sha3_256_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "sha3_256", data, string, usedforsecurity);
}

impl _hashlib_openssl_sha3_384_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "sha3_384", data, string, usedforsecurity);
}

impl _hashlib_openssl_sha3_512_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "sha3_512", data, string, usedforsecurity);
}

impl _hashlib_openssl_shake_128_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "shake_128", data, string, usedforsecurity);
}

impl _hashlib_openssl_shake_256_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    return call_hashlib_new(module, "shake_256", data, string, usedforsecurity);
}

impl pbkdf2_hmac_impl(
    module: ptr[PyObject],
    hash_name: str,
    password: BufferArgument,
    salt: BufferArgument,
    iterations: i64,
    dklen_obj: ptr[PyObject]
) -> ptr[PyObject] {
    digest = py_digest_by_name(module, hash_name, PY_HT_PBKDF2);
    if not digest {
        return NULL;
    }
    key_obj = NULL;
    dklen: i64 = 0;
    failed = True;
    if password.size() > INT_MAX {
        object_error(PyExc_OverflowError, "password is too long.");
    } elif salt.size() > INT_MAX {
        object_error(PyExc_OverflowError, "salt is too long.");
    } elif iterations < 1 {
        object_error(PyExc_ValueError, "iteration value must be greater than 0.");
    } elif iterations > INT_MAX {
        object_error(PyExc_OverflowError, "iteration value is too great.");
    } else {
        failed = False;
    }
    if not failed {
        if dklen_obj == Py_None {
            dklen = i64(EVP_MD_get_size(digest));
        } else {
            dklen = PyLong_AsLong(dklen_obj);
            failed = dklen == -1 and bool(PyErr_Occurred());
        }
    }
    if not failed {
        if dklen < 1 {
            object_error(PyExc_ValueError, "key length must be greater than 0.");
            failed = True;
        } elif dklen > INT_MAX {
            object_error(PyExc_OverflowError, "key length is too great.");
            failed = True;
        }
    }
    if not failed {
        key_obj = jacpy_bytes_from_memory(ptr(), dklen);
    }
    if key_obj {
        key = jacpy_bytes_address(key_obj);
        password_address = password.address();
        password_length = i32(password.size());
        salt_address = salt.address();
        salt_length = i32(salt.size());
        thread = PyEval_SaveThread();
        retval = PKCS5_PBKDF2_HMAC(
            password_address,
            password_length,
            salt_address,
            salt_length,
            i32(iterations),
            digest,
            i32(dklen),
            key
        );
        PyEval_RestoreThread(thread);
        if retval == 0 {
            jacpy_release(key_obj);
            key_obj = NULL;
            notify_ssl_error_occurred();
        }
    }
    EVP_MD_free(digest);
    return key_obj;
}

impl _hashlib_scrypt_impl(
    module: ptr[PyObject],
    password: BufferArgument,
    salt: BufferArgument,
    n: u64,
    r: u64,
    p: u64,
    maxmem: i64,
    dklen: i64
) -> ptr[PyObject] {
    if password.size() > INT_MAX {
        object_error(PyExc_OverflowError, "password is too long.");
        return NULL;
    }
    if salt.size() > INT_MAX {
        object_error(PyExc_OverflowError, "salt is too long.");
        return NULL;
    }
    if n < u64(2) or (n & (n - u64(1))) != u64(0) {
        object_error(PyExc_ValueError, "n must be a power of 2.");
        return NULL;
    }
    if maxmem < 0 or maxmem > INT_MAX {
        object_error(
            PyExc_ValueError, f"maxmem must be positive and smaller than {INT_MAX}"
        );
        return NULL;
    }
    if dklen < 1 or dklen > INT_MAX {
        object_error(
            PyExc_ValueError, f"dklen must be greater than 0 and smaller than {INT_MAX}"
        );
        return NULL;
    }

    retval = EVP_PBE_scrypt(
        ptr(), u64(0), ptr(), u64(0), n, r, p, u64(maxmem), ptr(), u64(0)
    );
    if retval == 0 {
        raise_ssl_error(
            PyExc_ValueError, "Invalid parameter combination for n, r, p, maxmem."
        );
        return NULL;
    }
    key_obj = jacpy_bytes_from_memory(ptr(), dklen);
    if not key_obj {
        return NULL;
    }
    key = jacpy_bytes_address(key_obj);
    password_address = password.address();
    password_length = u64(password.size());
    salt_address = salt.address();
    salt_length = u64(salt.size());
    thread = PyEval_SaveThread();
    retval = EVP_PBE_scrypt(
        password_address,
        password_length,
        salt_address,
        salt_length,
        n,
        r,
        p,
        u64(maxmem),
        key,
        u64(dklen)
    );
    PyEval_RestoreThread(thread);
    if retval == 0 {
        jacpy_release(key_obj);
        notify_ssl_error_occurred();
        return NULL;
    }
    return key_obj;
}

impl _hashlib_hmac_singleshot_impl(
    module: ptr[PyObject],
    key: BufferArgument,
    msg: BufferArgument,
    digest: ptr[PyObject]
) -> ptr[PyObject] {
    if key.size() > INT_MAX {
        object_error(PyExc_OverflowError, "key is too long.");
        return NULL;
    }
    if msg.size() > INT_MAX {
        object_error(PyExc_OverflowError, "msg is too long.");
        return NULL;
    }
    evp = py_digest_by_digestmod(module, digest, PY_HT_MAC);
    if not evp {
        return NULL;
    }
    md = PyMem_Malloc(u64(EVP_MAX_MD_SIZE));
    if not md {
        EVP_MD_free(evp);
        PyErr_NoMemory();
        return NULL;
    }
    md_len = u32(0);
    key_address = key.address();
    key_length = i32(key.size());
    msg_address = msg.address();
    msg_length = u64(msg.size());
    thread = PyEval_SaveThread();
    result = HMAC(
        evp, key_address, key_length, msg_address, msg_length, md, &mut md_len
    );
    PyEval_RestoreThread(thread);
    EVP_MD_free(evp);
    if not result {
        PyMem_Free(md);
        notify_ssl_error_occurred();
        return NULL;
    }
    output = jacpy_bytes_from_memory(md, i64(md_len));
    PyMem_Free(md);
    return output;
}

impl HMACState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl HMACState.clear {}

impl HMACState.drop {
    if self.ctx {
        HMAC_CTX_free(self.ctx);
    }
}

impl hmac_of(instance: ptr[PyObject]) -> HMACState | None {
    state = hash_state_of(instance, HMAC_token);
    if isinstance(state, HMACState) {
        return state;
    }
    return None;
}

impl hmac_update(state: HMACState, obj_: ptr[PyObject]) -> bool {
    view = hash_buffer(obj_);
    if view is None {
        return False;
    }
    address = view.address();
    size = view.size();
    if not state.lock.use_mutex
        and size >= HASHLIB_GIL_MINSIZE
        and not state.lock.enable() {
        view.close();
        return False;
    }
    r = i32(0);
    if state.lock.use_mutex {
        ctx = state.ctx;
        mutex = state.lock.lock;
        thread = PyEval_SaveThread();
        PyThread_acquire_lock(mutex, 1);
        r = HMAC_Update(ctx, address, u64(size));
        PyThread_release_lock(mutex);
        PyEval_RestoreThread(thread);
    } else {
        r = HMAC_Update(state.ctx, address, u64(size));
    }
    view.close();
    if r == 0 {
        notify_ssl_error_occurred();
        return False;
    }
    return True;
}

impl _hashlib_hmac_new_impl(
    module: ptr[PyObject],
    key: BufferArgument,
    msg_obj: ptr[PyObject],
    digestmod: ptr[PyObject]
) -> ptr[PyObject] {
    if key.size() > INT_MAX {
        object_error(PyExc_OverflowError, "key is too long.");
        return NULL;
    }
    if not digestmod {
        object_error(PyExc_TypeError, "Missing required parameter 'digestmod'.");
        return NULL;
    }
    digest = py_digest_by_digestmod(module, digestmod, PY_HT_MAC);
    if not digest {
        return NULL;
    }
    ctx = HMAC_CTX_new();
    if not ctx {
        EVP_MD_free(digest);
        PyErr_NoMemory();
        return NULL;
    }
    r = HMAC_Init_ex(ctx, key.address(), i32(key.size()), digest, ptr());
    EVP_MD_free(digest);
    if r == 0 {
        notify_ssl_error_occurred();
        HMAC_CTX_free(ctx);
        return NULL;
    }
    state = HMACState(lock=HashLock(), ctx=ctx);
    instance = hash_object_new(state_ref(module, STATE_HMAC_TYPE), HMAC_token, state);
    if not instance {
        return NULL;
    }
    if msg_obj and msg_obj != Py_None and not hmac_update(state, msg_obj) {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

impl locked_hmac_copy(target: ptr, state: HMACState) -> bool {
    state.lock.enter();
    result = HMAC_CTX_copy(target, state.ctx);
    state.lock.leave();
    return result != 0;
}

impl hmac_md(state: HMACState) -> ptr {
    md = HMAC_CTX_get_md(state.ctx);
    if not md {
        raise_ssl_error(PyExc_ValueError, "missing EVP_MD for HMAC context");
    }
    return md;
}

impl hmac_digest_size(state: HMACState) -> i64 {
    md = hmac_md(state);
    if not md {
        return 0;
    }
    digest_size = i64(EVP_MD_get_size(md)) & 0xFFFFFFFF;
    if digest_size == 0 {
        raise_ssl_error(PyExc_ValueError, "invalid digest size");
    }
    return digest_size;
}

impl _hashlib_HMAC_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    ctx = HMAC_CTX_new();
    if not ctx {
        return PyErr_NoMemory();
    }
    if not locked_hmac_copy(ctx, state) {
        HMAC_CTX_free(ctx);
        notify_ssl_error_occurred();
        return NULL;
    }
    return hash_object_new(
        Py_TYPE(receiver), HMAC_token, HMACState(lock=HashLock(), ctx=ctx)
    );
}

impl _hashlib_HMAC_update_impl(
    receiver: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None or not hmac_update(state, msg) {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

impl hmac_final(state: HMACState, as_hex: bool) -> ptr[PyObject] {
    digest_size = hmac_digest_size(state);
    if digest_size == 0 {
        return NULL;
    }
    buffer = PyMem_Malloc(u64(EVP_MAX_MD_SIZE));
    if not buffer {
        PyErr_NoMemory();
        return NULL;
    }
    temp_ctx = HMAC_CTX_new();
    if not temp_ctx {
        PyMem_Free(buffer);
        PyErr_NoMemory();
        return NULL;
    }
    if not locked_hmac_copy(temp_ctx, state) {
        HMAC_CTX_free(temp_ctx);
        PyMem_Free(buffer);
        notify_ssl_error_occurred();
        return NULL;
    }
    length = u32(digest_size);
    r = HMAC_Final(temp_ctx, buffer, &mut length);
    HMAC_CTX_free(temp_ctx);
    if r == 0 {
        PyMem_Free(buffer);
        notify_ssl_error_occurred();
        return NULL;
    }
    result = _Py_strhex(buffer, digest_size)
        if as_hex
        else jacpy_bytes_from_memory(buffer, digest_size);
    PyMem_Free(buffer);
    return result;
}

impl _hashlib_HMAC_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return hmac_final(state, False);
}

impl _hashlib_HMAC_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(receiver);
    if state is None {
        return NULL;
    }
    return hmac_final(state, True);
}

impl hmac_get_digest_size(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(instance);
    if state is None {
        return NULL;
    }
    digest_size = hmac_digest_size(state);
    return NULL if digest_size == 0 else PyLong_FromLong(digest_size);
}

impl hmac_get_block_size(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(instance);
    if state is None {
        return NULL;
    }
    md = hmac_md(state);
    return NULL if not md else PyLong_FromLong(i64(EVP_MD_get_block_size(md)));
}

impl hmac_get_name(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(instance);
    if state is None {
        return NULL;
    }
    md = hmac_md(state);
    if not md {
        return NULL;
    }
    digest_name = py_digest_name(md);
    if not digest_name {
        return NULL;
    }
    name = PyUnicode_FromFormat("hmac-%U", digest_name);
    jacpy_release(digest_name);
    return name;
}

impl hmac_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = hmac_of(instance);
    if state is None {
        return NULL;
    }
    md = hmac_md(state);
    if not md {
        return NULL;
    }
    digest_name = py_digest_name(md);
    if not digest_name {
        return NULL;
    }
    result = PyUnicode_FromFormat("<%U HMAC object @ %p>", digest_name, instance);
    jacpy_release(digest_name);
    return result;
}

impl _hashlib_get_fips_mode_impl(module: ptr[PyObject]) -> i32 {
    return EVP_default_properties_is_fips_enabled(ptr());
}

impl _hashlib_compare_digest_impl(
    module: ptr[PyObject], a: ptr[PyObject], b: ptr[PyObject]
) -> ptr[PyObject] {
    return compare_digest(a, b);
}

impl openssl_hash_name_mapper(md: ptr, argument: ptr) {
    if not md or i64(EVP_MD_get_type(md)) == NID_undef {
        return;
    }
    py_name = py_digest_name(md);
    if not py_name {
        name_mapper_state.error = True;
    } else {
        if PySet_Add(name_mapper_state.names, py_name) != 0 {
            name_mapper_state.error = True;
        }
        jacpy_release(py_name);
    }
}

impl hashlib_md_meth_names(module: ptr[PyObject]) -> bool {
    names = PyFrozenSet_New(NULL);
    if not names {
        return False;
    }
    name_mapper_state.names = names;
    name_mapper_state.error = False;
    EVP_MD_do_all_provided(ptr(), openssl_hash_name_mapper, ptr());
    name_mapper_state.names = NULL;
    if name_mapper_state.error {
        jacpy_release(names);
        return False;
    }
    return PyModule_Add(module, ptr[u8]("openssl_md_meth_names"), names) == 0;
}

impl hashlib_init_constructors(
    module: ptr[PyObject], methods: list[MethodDefinition]
) -> ptr[PyObject] {
    constructs = PyDict_New();
    if not constructs {
        return NULL;
    }
    for method in methods {
        if not method.name.startswith("openssl_") {
            continue;
        }
        name_obj = jacpy_unicode_from_text(method.name[8:]);
        if not name_obj {
            jacpy_release(constructs);
            return NULL;
        }
        func = jacpy_object_getattr_text(module, method.name);
        if not func {
            jacpy_release(name_obj);
            jacpy_release(constructs);
            return NULL;
        }
        rc = PyDict_SetItem(constructs, func, name_obj);
        jacpy_release(func);
        jacpy_release(name_obj);
        if rc < 0 {
            jacpy_release(constructs);
            return NULL;
        }
    }
    return constructs;
}

impl hashlib_exception -> ptr[PyObject] {
    return PyErr_NewException(
        "_hashlib.UnsupportedDigestmodError", PyExc_ValueError, NULL
    );
}

impl dict_proxy(mapping: ptr[PyObject]) -> ptr[PyObject] {
    return PyDictProxy_New(mapping);
}

impl add_object(module: ptr[PyObject], name: str, value: ptr[PyObject]) -> bool {
    return jacpy_module_add_object_ref_text(module, name, value) == 0;
}
