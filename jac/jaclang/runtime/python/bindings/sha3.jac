"""The _sha3 module: the four SHA-3 types over sha3_224's generated methods and
the two SHAKE types over shake_128's."""

import from jaclang.runtime.python.cpython_api {
    PyModule_AddIntConstant,
    PyModule_AddStringConstant,
    PyObject,
    Py_TYPE
}
import from jaclang.runtime.python.bindings.module {
    MethodDefinition,
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
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.sha3 {
    py_sha3_new_new,
    sha3_224_methods,
    shake_128_methods
}
import from jaclang.runtime.python.modules.hashlib { HASHLIB_GIL_MINSIZE }
import from jaclang.runtime.python.modules.sha3 {
    SHA3_token,
    SHA3_TYPES,
    get_block_size,
    get_capacity_bits,
    get_digest_size,
    get_name,
    get_rate_bits,
    get_shake_digest_size,
    get_shake_suffix,
    get_suffix
}

def:priv sha3_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, SHA3_token.definition_of(Py_TYPE(instance)));
}

def:priv sha3_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, SHA3_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

"""SHA3_TYPE_SLOTS and SHA3_TYPE_SPEC: an instantiable SHA-3 type."""
def:priv sha3_type(name: str, doc: str) -> TypeDefinition {
    return TypeDefinition(
        f"_sha3.{name}",
        doc,
        sha3_224_methods,
        u64(TypeFlags.IMMUTABLE.value | TypeFlags.GC.value),
        TypeHooks(create=py_sha3_new_new, dealloc=sha3_dealloc, traverse=sha3_traverse),
        [
            PropertyDefinition("block_size", PropertyCallbacks(read=get_block_size)),
            PropertyDefinition("name", PropertyCallbacks(read=get_name)),
            PropertyDefinition("digest_size", PropertyCallbacks(read=get_digest_size)),
            PropertyDefinition(
                "_capacity_bits", PropertyCallbacks(read=get_capacity_bits)
            ),
            PropertyDefinition("_rate_bits", PropertyCallbacks(read=get_rate_bits)),
            PropertyDefinition("_suffix", PropertyCallbacks(read=get_suffix))
        ]
    );
}

"""SHAKE_methods: copy and update are sha3_224's, digest and hexdigest take a
length."""
glob:priv SHAKE_METHODS: list[MethodDefinition] = [
         sha3_224_methods[0],
         shake_128_methods[0],
         shake_128_methods[1],
         sha3_224_methods[3]
     ];

"""A SHAKE type: SHAKE_METHODS and the SHAKE getters."""
def:priv shake_type(name: str, doc: str) -> TypeDefinition {
    return TypeDefinition(
        f"_sha3.{name}",
        doc,
        SHAKE_METHODS,
        u64(TypeFlags.IMMUTABLE.value | TypeFlags.GC.value),
        TypeHooks(create=py_sha3_new_new, dealloc=sha3_dealloc, traverse=sha3_traverse),
        [
            PropertyDefinition("block_size", PropertyCallbacks(read=get_block_size)),
            PropertyDefinition("name", PropertyCallbacks(read=get_name)),
            PropertyDefinition(
                "digest_size", PropertyCallbacks(read=get_shake_digest_size)
            ),
            PropertyDefinition(
                "_capacity_bits", PropertyCallbacks(read=get_capacity_bits)
            ),
            PropertyDefinition("_rate_bits", PropertyCallbacks(read=get_rate_bits)),
            PropertyDefinition("_suffix", PropertyCallbacks(read=get_shake_suffix))
        ]
    );
}

glob:priv sha3_types: list[TypeDefinition] = [
         sha3_type(
             "sha3_224",
             "sha3_224([data], *, usedforsecurity=True) -> SHA3 object\n\nReturn a new SHA3 hash object with a hashbit length of 28 bytes."
         ),
         sha3_type(
             "sha3_256",
             "sha3_256([data], *, usedforsecurity=True) -> SHA3 object\n\nReturn a new SHA3 hash object with a hashbit length of 32 bytes."
         ),
         sha3_type(
             "sha3_384",
             "sha3_384([data], *, usedforsecurity=True) -> SHA3 object\n\nReturn a new SHA3 hash object with a hashbit length of 48 bytes."
         ),
         sha3_type(
             "sha3_512",
             "sha3_512([data], *, usedforsecurity=True) -> SHA3 object\n\nReturn a new SHA3 hash object with a hashbit length of 64 bytes."
         ),
         shake_type(
             "shake_128",
             "shake_128([data], *, usedforsecurity=True) -> SHAKE object\n\nReturn a new SHAKE hash object."
         ),
         shake_type(
             "shake_256",
             "shake_256([data], *, usedforsecurity=True) -> SHAKE object\n\nReturn a new SHAKE hash object."
         )
     ];

def:priv execute(module: ptr[PyObject]) -> i32 {
    SHA3_token.handle = sha3_types[0].handle;
    for index in range(1, len(sha3_types)) {
        SHA3_token.share(sha3_types[index].handle);
    }
    for index in range(len(sha3_types)) {
        if not add_state_owned(
            module, index, SHA3_TYPES[index][0], sha3_types[index].create(module)
        ) {
            return i32(-1);
        }
    }
    if PyModule_AddStringConstant(module, "implementation", "HACL") < 0
        or PyModule_AddIntConstant(module, "_GIL_MINSIZE", HASHLIB_GIL_MINSIZE) < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_sha3", "", [], ModuleHooks(execute=execute), 6
     );

def:pub PyInit__sha3 -> ptr[PyObject] {
    return definition.initialize();
}
