def:priv sha256_dealloc(instance: ptr[PyObject]);

def:priv sha512_dealloc(instance: ptr[PyObject]);

def:priv sha256_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def:priv sha512_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def:priv sha256_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv sha512_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv digest_size_of(instance: ptr[PyObject], token: ClassToken) -> ptr[PyObject];

def:priv sha256_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv sha512_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv sha256_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv sha512_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

glob:priv FLAGS: u64 = u64(
         TypeFlags.DISALLOW_INSTANTIATION.value
             | TypeFlags.IMMUTABLE.value
             | TypeFlags.GC.value
     );

def:priv sha2_type(name: str, wide: bool) -> TypeDefinition;

glob:priv sha224_type = sha2_type("_sha2.SHA224Type", False),
     sha256_type = sha2_type("_sha2.SHA256Type", False),
     sha384_type = sha2_type("_sha2.SHA384Type", True),
     sha512_type = sha2_type("_sha2.SHA512Type", True);

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_sha2", "", module_methods, ModuleHooks(execute=execute), 4
     );

def:pub PyInit__sha2 -> ptr[PyObject];

impl sha256_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, SHA256Type_token.definition_of(Py_TYPE(instance)));
}

impl sha512_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, SHA512Type_token.definition_of(Py_TYPE(instance)));
}

impl sha256_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, SHA256Type_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

impl sha512_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, SHA512Type_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

impl sha256_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(SHA256_BLOCKSIZE);
}

impl sha512_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(SHA512_BLOCKSIZE);
}

impl digest_size_of(instance: ptr[PyObject], token: ClassToken) -> ptr[PyObject] {
    state = sha2_of(instance, token);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(state.digestsize);
}

impl sha256_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_size_of(instance, SHA256Type_token);
}

impl sha512_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_size_of(instance, SHA512Type_token);
}

impl sha256_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha2_of(instance, SHA256Type_token);
    if state is None {
        return NULL;
    }
    return jacpy_unicode_from_text("sha224" if state.digestsize == 28 else "sha256");
}

impl sha512_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha2_of(instance, SHA512Type_token);
    if state is None {
        return NULL;
    }
    return jacpy_unicode_from_text("sha512" if state.digestsize == 64 else "sha384");
}

impl sha2_type(name: str, wide: bool) -> TypeDefinition {
    if wide {
        return TypeDefinition(
            name,
            "",
            SHA512Type_methods,
            FLAGS,
            TypeHooks(dealloc=sha512_dealloc, traverse=sha512_traverse),
            [
                PropertyDefinition(
                    "block_size", PropertyCallbacks(read=sha512_block_size)
                ),
                PropertyDefinition("name", PropertyCallbacks(read=sha512_name)),
                PropertyDefinition(
                    "digest_size", PropertyCallbacks(read=sha512_digest_size)
                )
            ]
        );
    }
    return TypeDefinition(
        name,
        "",
        SHA256Type_methods,
        FLAGS,
        TypeHooks(dealloc=sha256_dealloc, traverse=sha256_traverse),
        [
            PropertyDefinition("block_size", PropertyCallbacks(read=sha256_block_size)),
            PropertyDefinition("name", PropertyCallbacks(read=sha256_name)),
            PropertyDefinition(
                "digest_size", PropertyCallbacks(read=sha256_digest_size)
            )
        ]
    );
}

impl execute(module: ptr[PyObject]) -> i32 {
    SHA256Type_token.handle = sha256_type.handle;
    SHA256Type_token.share(sha224_type.handle);
    SHA512Type_token.handle = sha512_type.handle;
    SHA512Type_token.share(sha384_type.handle);
    if not add_state_owned(module, 0, "SHA224Type", sha224_type.create(module))
        or not add_state_owned(module, 1, "SHA256Type", sha256_type.create(module))
        or not add_state_owned(module, 2, "SHA384Type", sha384_type.create(module))
        or not add_state_owned(module, 3, "SHA512Type", sha512_type.create(module))
        or PyModule_AddIntConstant(module, ptr[u8]("_GIL_MINSIZE"), HASHLIB_GIL_MINSIZE)
            < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl PyInit__sha2 -> ptr[PyObject] {
    return definition.initialize();
}
