def:priv evp_dealloc(instance: ptr[PyObject]);

def:priv hmac_dealloc(instance: ptr[PyObject]);

def:priv evp_get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv evp_get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv evp_get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv evpxof_get_digest_size(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv hmac_digest_size_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv hmac_block_size_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv hmac_name_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

glob:priv HASHTYPE_DOC: str = "HASH(name, string=b'')\n--\n\nA hash is an object used to calculate a checksum of a string of information.\n\nMethods:\n\nupdate() -- updates the current digest with an additional string\ndigest() -- return the current digest value\nhexdigest() -- return the current digest as a string of hexadecimal digits\ncopy() -- return a copy of the current hash object\n\nAttributes:\n\nname -- the hash algorithm being used by this object\ndigest_size -- number of bytes in this hashes output",
     HASHXOFTYPE_DOC: str = "HASHXOF(name, string=b'')\n--\n\nA hash is an object used to calculate a checksum of a string of information.\n\nMethods:\n\nupdate() -- updates the current digest with an additional string\ndigest(length) -- return the current digest value\nhexdigest(length) -- return the current digest as a string of hexadecimal digits\ncopy() -- return a copy of the current hash object\n\nAttributes:\n\nname -- the hash algorithm being used by this object\ndigest_size -- number of bytes in this hashes output",
     HMACTYPE_DOC: str = "The object used to calculate HMAC of a message.\n\nMethods:\n\nupdate() -- updates the current digest with an additional string\ndigest() -- return the current digest value\nhexdigest() -- return the current digest as a string of hexadecimal digits\ncopy() -- return a copy of the current hash object\n\nAttributes:\n\nname -- the name, including the hash algorithm used by this object\ndigest_size -- number of bytes in digest() output\n";

glob:priv HASH_FLAGS: u64 = u64(
         TypeFlags.BASETYPE.value
             | TypeFlags.DISALLOW_INSTANTIATION.value
             | TypeFlags.IMMUTABLE.value
     ),
     HMAC_FLAGS: u64 = u64(
         TypeFlags.DISALLOW_INSTANTIATION.value | TypeFlags.IMMUTABLE.value
     );

glob:priv evp_type = TypeDefinition(
         "_hashlib.HASH",
         HASHTYPE_DOC,
         HASH_methods,
         HASH_FLAGS,
         TypeHooks(dealloc=evp_dealloc, repr=evp_repr),
         [
             PropertyDefinition(
                 "digest_size", PropertyCallbacks(read=evp_get_digest_size)
             ),
             PropertyDefinition(
                 "block_size", PropertyCallbacks(read=evp_get_block_size)
             ),
             PropertyDefinition(
                 "name", PropertyCallbacks(read=evp_get_name), doc="algorithm name."
             )
         ]
     ),
     evpxof_type = TypeDefinition(
         "_hashlib.HASHXOF",
         HASHXOFTYPE_DOC,
         HASHXOF_methods,
         HASH_FLAGS,
         TypeHooks(),
         [
             PropertyDefinition(
                 "digest_size", PropertyCallbacks(read=evpxof_get_digest_size)
             )
         ]
     ),
     hmac_type = TypeDefinition(
         "_hashlib.HMAC",
         HMACTYPE_DOC,
         HMAC_methods,
         HMAC_FLAGS,
         TypeHooks(repr=hmac_repr, dealloc=hmac_dealloc),
         [
             PropertyDefinition(
                 "digest_size", PropertyCallbacks(read=hmac_digest_size_get)
             ),
             PropertyDefinition(
                 "block_size", PropertyCallbacks(read=hmac_block_size_get)
             ),
             PropertyDefinition("name", PropertyCallbacks(read=hmac_name_get))
         ]
     );

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_hashlib",
         "OpenSSL interface for hashlib module",
         module_methods,
         ModuleHooks(execute=execute),
         STATE_COUNT
     );

def:pub PyInit__hashlib -> ptr[PyObject];

impl evp_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, HASH_token.definition_of(Py_TYPE(instance)));
}

impl hmac_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, HMAC_token.definition_of(Py_TYPE(instance)));
}

impl evp_get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return evp_block_size(instance);
}

impl evp_get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return evp_digest_size(instance);
}

impl evp_get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return evp_name(instance);
}

impl evpxof_get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(0);
}

impl hmac_digest_size_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return hmac_get_digest_size(instance);
}

impl hmac_block_size_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return hmac_get_block_size(instance);
}

impl hmac_name_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return hmac_get_name(instance);
}

impl execute(module: ptr[PyObject]) -> i32 {
    HASH_token.handle = evp_type.handle;
    HMAC_token.handle = hmac_type.handle;

    jacpy_binding_module_native_set(module, hashlib_state_new());

    if not add_state_owned(module, STATE_EVP_TYPE, "HASH", evp_type.create(module)) {
        return i32(-1);
    }

    if not add_state_owned(
        module,
        STATE_EVPXOF_TYPE,
        "HASHXOF",
        evpxof_type.create(module, jacpy_binding_state_get(module, i64(STATE_EVP_TYPE)))
    ) {
        return i32(-1);
    }

    if not add_state_owned(module, STATE_HMAC_TYPE, "HMAC", hmac_type.create(module)) {
        return i32(-1);
    }
    if not hashlib_md_meth_names(module) {
        return i32(-1);
    }

    constructs = hashlib_init_constructors(module, module_methods);
    if not constructs {
        return i32(-1);
    }
    jacpy_binding_state_set(module, i64(STATE_CONSTRUCTS), constructs);
    proxy = dict_proxy(constructs);
    jacpy_release(constructs);
    if PyModule_Add(module, ptr[u8]("_constructors"), proxy) < 0 {
        return i32(-1);
    }

    error = hashlib_exception();
    if not error {
        return i32(-1);
    }
    jacpy_binding_state_set(module, i64(STATE_UNSUPPORTED_DIGESTMOD_ERROR), error);
    jacpy_release(error);
    if not add_object(
        module,
        "UnsupportedDigestmodError",
        jacpy_binding_state_get(module, i64(STATE_UNSUPPORTED_DIGESTMOD_ERROR))
    ) {
        return i32(-1);
    }

    if PyModule_AddIntConstant(module, ptr[u8]("_GIL_MINSIZE"), HASHLIB_GIL_MINSIZE)
        < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl PyInit__hashlib -> ptr[PyObject] {
    return definition.initialize();
}
