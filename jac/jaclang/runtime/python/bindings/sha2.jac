"""The _sha2 module: SHA224Type and SHA256Type over SHA256Type's generated
methods, SHA384Type and SHA512Type over SHA512Type's."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyLong_FromLong,
    PyModule_AddIntConstant,
    PyObject,
    PyUnicode_FromString,
    Py_TYPE
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    PropertyCallbacks
}
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.sha2 {
    SHA256Type_methods,
    SHA512Type_methods,
    module_methods
}
import from jaclang.runtime.python.modules.hashlib { HASHLIB_GIL_MINSIZE }
import from jaclang.runtime.python.modules.sha2 {
    SHA256Type_token,
    SHA512Type_token,
    SHA256_BLOCKSIZE,
    SHA512_BLOCKSIZE,
    sha2_of
}

def:priv sha256_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, SHA256Type_token.definition_of(Py_TYPE(instance)));
}

def:priv sha512_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, SHA512Type_token.definition_of(Py_TYPE(instance)));
}

def:priv sha256_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, SHA256Type_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

def:priv sha512_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, SHA512Type_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

def:priv sha256_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(SHA256_BLOCKSIZE);
}

def:priv sha512_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(SHA512_BLOCKSIZE);
}

def:priv digest_size_of(instance: ptr[PyObject], token: ClassToken) -> ptr[PyObject] {
    state = sha2_of(instance, token);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(state.digestsize);
}

def:priv sha256_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_size_of(instance, SHA256Type_token);
}

def:priv sha512_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_size_of(instance, SHA512Type_token);
}

def:priv sha256_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha2_of(instance, SHA256Type_token);
    if state is None {
        return NULL;
    }
    return PyUnicode_FromString("sha224" if state.digestsize == 28 else "sha256");
}

def:priv sha512_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = sha2_of(instance, SHA512Type_token);
    if state is None {
        return NULL;
    }
    return PyUnicode_FromString("sha512" if state.digestsize == 64 else "sha384");
}

glob:priv FLAGS: u64 = u64(
         TypeFlags.DISALLOW_INSTANTIATION.value
             | TypeFlags.IMMUTABLE.value
             | TypeFlags.GC.value
     );

"""One of the four types; `wide` selects SHA512Type's methods and getters."""
def:priv sha2_type(name: str, wide: bool) -> TypeDefinition {
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

glob:priv sha224_type = sha2_type("_sha2.SHA224Type", False),
     sha256_type = sha2_type("_sha2.SHA256Type", False),
     sha384_type = sha2_type("_sha2.SHA384Type", True),
     sha512_type = sha2_type("_sha2.SHA512Type", True);

def:priv execute(module: ptr[PyObject]) -> i32 {
    SHA256Type_token.bind(sha256_type.handle);
    SHA256Type_token.share(sha224_type.handle);
    SHA512Type_token.bind(sha512_type.handle);
    SHA512Type_token.share(sha384_type.handle);
    if not add_state_owned(module, 0, "SHA224Type", sha224_type.create(module))
        or not add_state_owned(module, 1, "SHA256Type", sha256_type.create(module))
        or not add_state_owned(module, 2, "SHA384Type", sha384_type.create(module))
        or not add_state_owned(module, 3, "SHA512Type", sha512_type.create(module))
        or PyModule_AddIntConstant(module, "_GIL_MINSIZE", HASHLIB_GIL_MINSIZE) < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_sha2", "", module_methods, ModuleHooks(execute=execute), 4
     );

def:pub PyInit__sha2 -> ptr[PyObject] {
    return definition.initialize();
}
