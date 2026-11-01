"""BLAKE2b and BLAKE2s hash objects; derived from CPython 3.14.6
Modules/blake2module.c. See ../LICENSE.cpython. The digests are the pure-Jac
BLAKE2 cores of na_stdlib/_digest.jac, which take the full parameter block.
"""

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

def:priv parameter_size(view: BufferArgument, capacity: i32, kind: str) -> i64;

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

def _blake2_blake2b_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _blake2_blake2b_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

impl parameter_size(view: BufferArgument, capacity: i32, kind: str) -> i64 {
    size = view.size() if bool(view.view) else 0;
    if size > i64(capacity) {
        object_error(PyExc_ValueError, f"maximum {kind} length is {capacity} bytes");
        return -1;
    }
    return size;
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
    out_bytes = HACL_HASH_BLAKE2B_OUT_BYTES if blake2b else HACL_HASH_BLAKE2S_OUT_BYTES;
    if digest_size <= 0 or digest_size > out_bytes {
        name = "Blake2b" if blake2b else "Blake2s";
        object_error(
            PyExc_ValueError,
            f"digest_size for {name} must be between 1 and {out_bytes} bytes, here it is {digest_size}"
        );
        return NULL;
    }
    salt_size = parameter_size(
        salt,
        HACL_HASH_BLAKE2B_SALT_BYTES if blake2b else HACL_HASH_BLAKE2S_SALT_BYTES,
        "salt"
    );
    if salt_size < 0 {
        return NULL;
    }
    person_size = parameter_size(
        person,
        HACL_HASH_BLAKE2B_PERSONAL_BYTES
            if blake2b
            else HACL_HASH_BLAKE2S_PERSONAL_BYTES,
        "person"
    );
    if person_size < 0
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
        return NULL;
    }
    key_size = parameter_size(
        key,
        HACL_HASH_BLAKE2B_KEY_BYTES if blake2b else HACL_HASH_BLAKE2S_KEY_BYTES,
        "key"
    );
    if key_size < 0 {
        return NULL;
    }
    core = new_blake2(
        blake2b,
        int(digest_size),
        int(key.address()) if key_size > 0 else 0,
        int(key_size),
        int(salt.address()) if salt_size > 0 else 0,
        int(salt_size),
        int(person.address()) if person_size > 0 else 0,
        int(person_size),
        int(fanout),
        int(depth),
        int(leaf_size),
        node_offset,
        int(node_depth),
        int(inner_size),
        last_node
    );
    return digest_object(type, Blake2_token, core, data);
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
    return digest_copy(receiver, Blake2_token);
}

impl _blake2_blake2b_update_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject] {
    return digest_update(receiver, Blake2_token, data);
}

impl _blake2_blake2b_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, Blake2_token, False);
}

impl _blake2_blake2b_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, Blake2_token, True);
}

impl get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_property(instance, Blake2_token, 0);
}

impl get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_property(instance, Blake2_token, 2);
}

impl get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_property(instance, Blake2_token, 1);
}
