import from c {
    def _Py_LibHacl_Hacl_Hash_Blake2s_malloc_with_params_and_key(
        p: &mut Pinned[Hacl_Hash_Blake2b_blake2_params], last_node: i32, k: ptr
    ) -> ptr;  def _Py_LibHacl_Hacl_Hash_Blake2b_malloc_with_params_and_key(
        p: &mut Pinned[Hacl_Hash_Blake2b_blake2_params], last_node: i32, k: ptr
    ) -> ptr;  def _Py_LibHacl_Hacl_Hash_Blake2s_update(
        state: ptr, chunk: ptr, chunk_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_Blake2b_update(
        state: ptr, chunk: ptr, chunk_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_Blake2s_digest(s: ptr, dst: ptr) -> u8;  def _Py_LibHacl_Hacl_Hash_Blake2b_digest(
        s: ptr, dst: ptr
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_Blake2s_copy(state: ptr) -> ptr;  def _Py_LibHacl_Hacl_Hash_Blake2b_copy(
        state: ptr
    ) -> ptr;  def _Py_LibHacl_Hacl_Hash_Blake2s_free(state: ptr);  def _Py_LibHacl_Hacl_Hash_Blake2b_free(
        state: ptr
    );
}

glob Blake2_token = ClassToken();

glob HACL_HASH_BLAKE2B_BLOCK_BYTES: i32 = 128,
     HACL_HASH_BLAKE2B_OUT_BYTES: i32 = 64,
     HACL_HASH_BLAKE2B_KEY_BYTES: i32 = 64,
     HACL_HASH_BLAKE2B_SALT_BYTES: i32 = 16,
     HACL_HASH_BLAKE2B_PERSONAL_BYTES: i32 = 16,
     HACL_HASH_BLAKE2S_BLOCK_BYTES: i32 = 64,
     HACL_HASH_BLAKE2S_OUT_BYTES: i32 = 32,
     HACL_HASH_BLAKE2S_KEY_BYTES: i32 = 32,
     HACL_HASH_BLAKE2S_SALT_BYTES: i32 = 8,
     HACL_HASH_BLAKE2S_PERSONAL_BYTES: i32 = 8;

glob:priv BLAKE2S: int = 0,
     BLAKE2B: int = 1,
     BLAKE2S_128: int = 2,
     BLAKE2B_256: int = 3,
     SIMD128: i64 = 1,
     SIMD256: i64 = 2;

obj Blake2State(NativeState) {
    has lock: HashLock,
        hash_state: ptr = ptr(),
        variant: int = 0,
        digest_size: i64 = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

def:priv is_blake2b(variant: int) -> bool;

def:priv blake2_free(variant: int, hacl: ptr);

def:priv blake2_copy(variant: int, hacl: ptr) -> ptr;

def:priv blake2b_update(hacl: ptr, address: ptr, size: i64);

def:priv blake2s_update(hacl: ptr, address: ptr, size: i64);

def:priv blake2b_digest(hacl: ptr, output: ptr) -> i64;

def:priv blake2s_digest(hacl: ptr, output: ptr) -> i64;

def:priv blake2_of(instance: ptr[PyObject]) -> Blake2State | None;

def:priv select_variant(blake2b: bool) -> int;

def:priv feed(state: Blake2State, data: ptr[PyObject]) -> bool;

def:priv parameter_bytes(
    view: BufferArgument, block: ptr, capacity: i32, kind: str
) -> bool;

def:priv blake2_new(
    type: ptr[PyObject],
    blake2b: bool,
    data: ptr[PyObject],
    digest_size: i32,
    key: BufferArgument,
    salt: BufferArgument,
    person: BufferArgument,
    fanout: i32,
    depth: i32,
    leaf_size: u64,
    node_offset: u64,
    node_depth: i32,
    inner_size: i32,
    last_node: bool
) -> ptr[PyObject];

def:priv check_tree(
    blake2b: bool,
    fanout: i32,
    depth: i32,
    leaf_size: u64,
    node_offset: u64,
    node_depth: i32,
    inner_size: i32,
    out_bytes: i32
) -> bool;

def py_blake2b_new_impl(
    type: ptr[PyObject],
    data_obj: ptr[PyObject],
    digest_size: i32,
    key: BufferArgument,
    salt: BufferArgument,
    person: BufferArgument,
    fanout: i32,
    depth: i32,
    leaf_size: u64,
    node_offset: u64,
    node_depth: i32,
    inner_size: i32,
    last_node: bool,
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def py_blake2s_new_impl(
    type: ptr[PyObject],
    data_obj: ptr[PyObject],
    digest_size: i32,
    key: BufferArgument,
    salt: BufferArgument,
    person: BufferArgument,
    fanout: i32,
    depth: i32,
    leaf_size: u64,
    node_offset: u64,
    node_depth: i32,
    inner_size: i32,
    last_node: bool,
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _blake2_blake2b_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _blake2_blake2b_update_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject];

def:priv blake2_digest(receiver: ptr[PyObject], as_hex: bool) -> ptr[PyObject];

def _blake2_blake2b_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _blake2_blake2b_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

impl Blake2State.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl Blake2State.clear {}

impl Blake2State.drop {
    if self.hash_state {
        blake2_free(self.variant, self.hash_state);
    }
}

impl is_blake2b(variant: int) -> bool {
    return variant == BLAKE2B or variant == BLAKE2B_256;
}

impl blake2_free(variant: int, hacl: ptr) {
    if variant == BLAKE2B_256 {
        simd256_free(hacl);
    } elif variant == BLAKE2S_128 {
        simd128_free(hacl);
    } elif variant == BLAKE2B {
        _Py_LibHacl_Hacl_Hash_Blake2b_free(hacl);
    } else {
        _Py_LibHacl_Hacl_Hash_Blake2s_free(hacl);
    }
}

impl blake2_copy(variant: int, hacl: ptr) -> ptr {
    if variant == BLAKE2B_256 {
        return simd256_copy(hacl);
    }
    if variant == BLAKE2S_128 {
        return simd128_copy(hacl);
    }
    if variant == BLAKE2B {
        return _Py_LibHacl_Hacl_Hash_Blake2b_copy(hacl);
    }
    return _Py_LibHacl_Hacl_Hash_Blake2s_copy(hacl);
}

impl blake2b_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_Blake2b_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor += UINT32_MAX;
    }
    _Py_LibHacl_Hacl_Hash_Blake2b_update(hacl, cursor, u32(remaining));
}

impl blake2s_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_Blake2s_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor += UINT32_MAX;
    }
    _Py_LibHacl_Hacl_Hash_Blake2s_update(hacl, cursor, u32(remaining));
}

impl blake2b_digest(hacl: ptr, output: ptr) -> i64 {
    return i64(_Py_LibHacl_Hacl_Hash_Blake2b_digest(hacl, output));
}

impl blake2s_digest(hacl: ptr, output: ptr) -> i64 {
    return i64(_Py_LibHacl_Hacl_Hash_Blake2s_digest(hacl, output));
}

impl blake2_of(instance: ptr[PyObject]) -> Blake2State | None {
    state = hash_state_of(instance, Blake2_token);
    if isinstance(state, Blake2State) {
        return state;
    }
    return None;
}

impl select_variant(blake2b: bool) -> int {
    features = jacpy_hacl_simd_features();
    if blake2b {
        return BLAKE2B_256 if (features & SIMD256) != 0 else BLAKE2B;
    }
    return BLAKE2S_128 if (features & SIMD128) != 0 else BLAKE2S;
}

impl feed(state: Blake2State, data: ptr[PyObject]) -> bool {
    if state.variant == BLAKE2B_256 {
        return hash_initial_data(state.hash_state, data, simd256_update);
    }
    if state.variant == BLAKE2S_128 {
        return hash_initial_data(state.hash_state, data, simd128_update);
    }
    if state.variant == BLAKE2B {
        return hash_initial_data(state.hash_state, data, blake2b_update);
    }
    return hash_initial_data(state.hash_state, data, blake2s_update);
}

impl parameter_bytes(
    view: BufferArgument, block: ptr, capacity: i32, kind: str
) -> bool {
    jacpy_memory_zero(block, i64(capacity));
    if bool(view.view) and view.size() > 0 {
        if view.size() > i64(capacity) {
            object_error(
                PyExc_ValueError, f"maximum {kind} length is {capacity} bytes"
            );
            return False;
        }
        jacpy_memory_copy(block, view.address(), view.size());
    }
    return True;
}

impl blake2_new(
    type: ptr[PyObject],
    blake2b: bool,
    data: ptr[PyObject],
    digest_size: i32,
    key: BufferArgument,
    salt: BufferArgument,
    person: BufferArgument,
    fanout: i32,
    depth: i32,
    leaf_size: u64,
    node_offset: u64,
    node_depth: i32,
    inner_size: i32,
    last_node: bool
) -> ptr[PyObject] {
    variant = select_variant(blake2b);
    out_bytes = HACL_HASH_BLAKE2B_OUT_BYTES if blake2b else HACL_HASH_BLAKE2S_OUT_BYTES;
    if digest_size <= 0 or digest_size > out_bytes {
        name = "Blake2b" if blake2b else "Blake2s";
        object_error(
            PyExc_ValueError,
            f"digest_size for {name} must be between 1 and {out_bytes} bytes, here it is {digest_size}"
        );
        return NULL;
    }
    blocks = PyMem_Malloc(
        u64(HACL_HASH_BLAKE2B_SALT_BYTES + HACL_HASH_BLAKE2B_PERSONAL_BYTES)
    );
    if not blocks {
        PyErr_NoMemory();
        return NULL;
    }
    salt_block = blocks;
    personal_block = blocks + HACL_HASH_BLAKE2B_SALT_BYTES;
    if not parameter_bytes(
        salt,
        salt_block,
        HACL_HASH_BLAKE2B_SALT_BYTES if blake2b else HACL_HASH_BLAKE2S_SALT_BYTES,
        "salt"
    )
        or not parameter_bytes(
            person,
            personal_block,
            HACL_HASH_BLAKE2B_PERSONAL_BYTES
                if blake2b
                else HACL_HASH_BLAKE2S_PERSONAL_BYTES,
            "person"
        )
        or not check_tree(
            blake2b,
            fanout,
            depth,
            leaf_size,
            node_offset,
            node_depth,
            inner_size,
            out_bytes
        ) {
        PyMem_Free(blocks);
        return NULL;
    }
    key_bytes = HACL_HASH_BLAKE2B_KEY_BYTES if blake2b else HACL_HASH_BLAKE2S_KEY_BYTES;
    key_length = key.size() if bool(key.view) else 0;
    if key_length > i64(key_bytes) {
        object_error(PyExc_ValueError, f"maximum key length is {key_bytes} bytes");
        PyMem_Free(blocks);
        return NULL;
    }
    key_address = key.address() if bool(key.view) else ptr();
    params = pin(
        Hacl_Hash_Blake2b_blake2_params(
            digest_length=u8(digest_size),
            key_length=u8(key_length),
            fanout=u8(fanout),
            depth=u8(depth),
            leaf_length=u32(leaf_size),
            node_offset=node_offset,
            node_depth=u8(node_depth),
            inner_length=u8(inner_size),
            salt=salt_block,
            personal=personal_block
        )
    );
    last = i32(1) if last_node else i32(0);
    hacl = ptr();
    if variant == BLAKE2B_256 {
        hacl = simd256_malloc(&mut params, last, key_address);
    } elif variant == BLAKE2S_128 {
        hacl = simd128_malloc(&mut params, last, key_address);
    } elif variant == BLAKE2B {
        hacl = _Py_LibHacl_Hacl_Hash_Blake2b_malloc_with_params_and_key(
            &mut params, last, key_address
        );
    } else {
        hacl = _Py_LibHacl_Hacl_Hash_Blake2s_malloc_with_params_and_key(
            &mut params, last, key_address
        );
    }
    PyMem_Free(blocks);
    if not hacl {
        PyErr_NoMemory();
        return NULL;
    }
    state = Blake2State(
        hash_state=hacl, lock=HashLock(), variant=variant, digest_size=i64(digest_size)
    );
    instance = hash_object_new(type, Blake2_token, state);
    if not instance {
        return NULL;
    }
    if data and not feed(state, data) {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

impl check_tree(
    blake2b: bool,
    fanout: i32,
    depth: i32,
    leaf_size: u64,
    node_offset: u64,
    node_depth: i32,
    inner_size: i32,
    out_bytes: i32
) -> bool {
    if fanout < 0 or fanout > 255 {
        object_error(PyExc_ValueError, "fanout must be between 0 and 255");
        return False;
    }
    if depth <= 0 or depth > 255 {
        object_error(PyExc_ValueError, "depth must be between 1 and 255");
        return False;
    }
    if leaf_size > u64(0xFFFFFFFF) {
        object_error(PyExc_OverflowError, "leaf_size is too large");
        return False;
    }
    if not blake2b and node_offset > u64(0xFFFFFFFFFFFF) {
        object_error(PyExc_OverflowError, "node_offset is too large");
        return False;
    }
    if node_depth < 0 or node_depth > 255 {
        object_error(PyExc_ValueError, "node_depth must be between 0 and 255");
        return False;
    }
    if inner_size < 0 or inner_size > out_bytes {
        object_error(
            PyExc_ValueError, f"inner_size must be between 0 and is {out_bytes}"
        );
        return False;
    }
    return True;
}

impl py_blake2b_new_impl(
    type: ptr[PyObject],
    data_obj: ptr[PyObject],
    digest_size: i32,
    key: BufferArgument,
    salt: BufferArgument,
    person: BufferArgument,
    fanout: i32,
    depth: i32,
    leaf_size: u64,
    node_offset: u64,
    node_depth: i32,
    inner_size: i32,
    last_node: bool,
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    (given, data) = data_argument(data_obj, string);
    if given < 0 {
        return NULL;
    }
    return blake2_new(
        type,
        True,
        data,
        digest_size,
        key,
        salt,
        person,
        fanout,
        depth,
        leaf_size,
        node_offset,
        node_depth,
        inner_size,
        last_node
    );
}

impl py_blake2s_new_impl(
    type: ptr[PyObject],
    data_obj: ptr[PyObject],
    digest_size: i32,
    key: BufferArgument,
    salt: BufferArgument,
    person: BufferArgument,
    fanout: i32,
    depth: i32,
    leaf_size: u64,
    node_offset: u64,
    node_depth: i32,
    inner_size: i32,
    last_node: bool,
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    (given, data) = data_argument(data_obj, string);
    if given < 0 {
        return NULL;
    }
    return blake2_new(
        type,
        False,
        data,
        digest_size,
        key,
        salt,
        person,
        fanout,
        depth,
        leaf_size,
        node_offset,
        node_depth,
        inner_size,
        last_node
    );
}

impl _blake2_blake2b_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = blake2_of(receiver);
    if state is None {
        return NULL;
    }
    state.lock.enter();
    hacl = blake2_copy(state.variant, state.hash_state);
    state.lock.leave();
    if not hacl {
        PyErr_NoMemory();
        return NULL;
    }
    return hash_object_new(
        Py_TYPE(receiver),
        Blake2_token,
        Blake2State(
            hash_state=hacl,
            lock=HashLock(),
            variant=state.variant,
            digest_size=state.digest_size
        )
    );
}

impl _blake2_blake2b_update_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject] {
    state = blake2_of(receiver);
    if state is None {
        return NULL;
    }
    if state.variant == BLAKE2B_256 {
        return hash_update(state.lock, state.hash_state, data, simd256_update);
    }
    if state.variant == BLAKE2S_128 {
        return hash_update(state.lock, state.hash_state, data, simd128_update);
    }
    if state.variant == BLAKE2B {
        return hash_update(state.lock, state.hash_state, data, blake2b_update);
    }
    return hash_update(state.lock, state.hash_state, data, blake2s_update);
}

impl blake2_digest(receiver: ptr[PyObject], as_hex: bool) -> ptr[PyObject] {
    state = blake2_of(receiver);
    if state is None {
        return NULL;
    }
    capacity = i64(HACL_HASH_BLAKE2B_OUT_BYTES);
    if state.variant == BLAKE2B_256 {
        return hash_digest(
            state.lock, state.hash_state, capacity, -1, simd256_digest, as_hex
        );
    }
    if state.variant == BLAKE2S_128 {
        return hash_digest(
            state.lock, state.hash_state, capacity, -1, simd128_digest, as_hex
        );
    }
    if state.variant == BLAKE2B {
        return hash_digest(
            state.lock, state.hash_state, capacity, -1, blake2b_digest, as_hex
        );
    }
    return hash_digest(
        state.lock, state.hash_state, capacity, -1, blake2s_digest, as_hex
    );
}

impl _blake2_blake2b_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return blake2_digest(receiver, False);
}

impl _blake2_blake2b_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return blake2_digest(receiver, True);
}

impl get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = blake2_of(instance);
    if state is None {
        return NULL;
    }
    return jacpy_unicode_from_text(
        "blake2b" if is_blake2b(state.variant) else "blake2s"
    );
}

impl get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = blake2_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(
        i64(
            HACL_HASH_BLAKE2B_BLOCK_BYTES
                if is_blake2b(state.variant)
                else HACL_HASH_BLAKE2S_BLOCK_BYTES
        )
    );
}

impl get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = blake2_of(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(state.digest_size);
}
