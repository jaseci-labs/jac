"""The _hashlib module: the HASH, HASHXOF and HMAC types over the generated
clinic tables, and the module's execution slots in Modules/_hashopenssl.c's
order."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyLong_FromLong,
    PyModule_Add,
    PyModule_AddIntConstant,
    PyObject,
    Py_TYPE,
    jacpy_release
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_module_native_set,
    jacpy_binding_state_get,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    PropertyCallbacks,
    PropertyDefinition,
    TypeDefinition,
    TypeFlags,
    TypeHooks
}
import from jaclang.runtime.python.bindings.payload { dispose_payload }
import from jaclang.runtime.python.bindings.clinic.hashopenssl {
    HASHXOF_methods,
    HASH_methods,
    HMAC_methods,
    module_methods
}
import from jaclang.runtime.python.modules.hashlib { HASHLIB_GIL_MINSIZE }
import from jaclang.runtime.python.modules.hashopenssl {
    HASH_token,
    HMAC_token,
    STATE_CONSTRUCTS,
    STATE_COUNT,
    STATE_EVPXOF_TYPE,
    STATE_EVP_TYPE,
    STATE_HMAC_TYPE,
    STATE_UNSUPPORTED_DIGESTMOD_ERROR,
    add_object,
    dict_proxy,
    evp_block_size,
    evp_digest_size,
    evp_name,
    evp_repr,
    hashlib_exception,
    hashlib_init_constructors,
    hashlib_md_meth_names,
    hashlib_state_new,
    hmac_get_block_size,
    hmac_get_digest_size,
    hmac_get_name,
    hmac_repr
}

def:priv evp_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, HASH_token.definition_of(Py_TYPE(instance)));
}

def:priv hmac_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, HMAC_token.definition_of(Py_TYPE(instance)));
}

def:priv evp_get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return evp_block_size(instance);
}

def:priv evp_get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return evp_digest_size(instance);
}

def:priv evp_get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return evp_name(instance);
}

def:priv evpxof_get_digest_size(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return PyLong_FromLong(0);
}

def:priv hmac_digest_size_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return hmac_get_digest_size(instance);
}

def:priv hmac_block_size_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return hmac_get_block_size(instance);
}

def:priv hmac_name_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return hmac_get_name(instance);
}

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

def:priv execute(module: ptr[PyObject]) -> i32 {
    HASH_token.handle = evp_type.handle;
    HMAC_token.handle = hmac_type.handle;
    # hashlib_init_hashtable
    jacpy_binding_module_native_set(module, hashlib_state_new());
    # hashlib_init_evptype
    if not add_state_owned(module, STATE_EVP_TYPE, "HASH", evp_type.create(module)) {
        return i32(-1);
    }
    # hashlib_init_evpxoftype
    if not add_state_owned(
        module,
        STATE_EVPXOF_TYPE,
        "HASHXOF",
        evpxof_type.create(module, jacpy_binding_state_get(module, i64(STATE_EVP_TYPE)))
    ) {
        return i32(-1);
    }
    # hashlib_init_hmactype
    if not add_state_owned(module, STATE_HMAC_TYPE, "HMAC", hmac_type.create(module)) {
        return i32(-1);
    }
    if not hashlib_md_meth_names(module) {
        return i32(-1);
    }
    # hashlib_init_constructors
    constructs = hashlib_init_constructors(module, module_methods);
    if not constructs {
        return i32(-1);
    }
    jacpy_binding_state_set(module, i64(STATE_CONSTRUCTS), constructs);
    proxy = dict_proxy(constructs);
    jacpy_release(constructs);
    if PyModule_Add(module, "_constructors", proxy) < 0 {
        return i32(-1);
    }
    # hashlib_exception
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
    # hashlib_constants
    if PyModule_AddIntConstant(module, "_GIL_MINSIZE", HASHLIB_GIL_MINSIZE) < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_hashlib",
         "OpenSSL interface for hashlib module",
         module_methods,
         ModuleHooks(execute=execute),
         STATE_COUNT
     );

def:pub PyInit__hashlib -> ptr[PyObject] {
    return definition.initialize();
}
