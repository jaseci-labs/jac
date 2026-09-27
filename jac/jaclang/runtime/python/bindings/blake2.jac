"""The _blake2 module: blake2b and blake2s over blake2b's generated methods;
only their constructors differ."""

import from jaclang.runtime.python.cpython_api {
    PyDict_SetItemString,
    PyLong_FromLong,
    PyModule_AddIntConstant,
    PyObject,
    PyType_GetDict,
    Py_TYPE,
    jacpy_release
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_state_get
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
import from jaclang.runtime.python.bindings.clinic.blake2 {
    blake2b_doc,
    blake2b_methods,
    blake2s_doc,
    py_blake2b_new_new,
    py_blake2s_new_new
}
import from jaclang.runtime.python.modules.hashlib { HASHLIB_GIL_MINSIZE }
import from jaclang.runtime.python.modules.blake2 {
    Blake2_token,
    HACL_HASH_BLAKE2B_KEY_BYTES,
    HACL_HASH_BLAKE2B_OUT_BYTES,
    HACL_HASH_BLAKE2B_PERSONAL_BYTES,
    HACL_HASH_BLAKE2B_SALT_BYTES,
    HACL_HASH_BLAKE2S_KEY_BYTES,
    HACL_HASH_BLAKE2S_OUT_BYTES,
    HACL_HASH_BLAKE2S_PERSONAL_BYTES,
    HACL_HASH_BLAKE2S_SALT_BYTES,
    get_block_size,
    get_digest_size,
    get_name
}

def:priv blake2_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, Blake2_token.definition_of(Py_TYPE(instance)));
}

def:priv blake2_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, Blake2_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

glob:priv PROPERTIES: list[PropertyDefinition] = [
         PropertyDefinition("name", PropertyCallbacks(read=get_name)),
         PropertyDefinition("block_size", PropertyCallbacks(read=get_block_size)),
         PropertyDefinition("digest_size", PropertyCallbacks(read=get_digest_size))
     ];

glob:priv blake2b_type = TypeDefinition(
         "_blake2.blake2b",
         blake2b_doc,
         blake2b_methods,
         u64(TypeFlags.IMMUTABLE.value | TypeFlags.GC.value),
         TypeHooks(
             create=py_blake2b_new_new, dealloc=blake2_dealloc, traverse=blake2_traverse
         ),
         PROPERTIES
     ),
     blake2s_type = TypeDefinition(
         "_blake2.blake2s",
         blake2s_doc,
         blake2b_methods,
         u64(TypeFlags.IMMUTABLE.value | TypeFlags.GC.value),
         TypeHooks(
             create=py_blake2s_new_new, dealloc=blake2_dealloc, traverse=blake2_traverse
         ),
         PROPERTIES
     );

"""ADD_INT: a constant in the type's own dictionary."""
def:priv add_type_int(type_dict: ptr[PyObject], name: str, value: i32) -> bool {
    number = PyLong_FromLong(i64(value));
    if not number {
        return False;
    }
    result = PyDict_SetItemString(type_dict, name, number);
    jacpy_release(number);
    return result == 0;
}

"""One type, its size constants and the module's copies of them."""
def:priv add_blake2_type(
    module: ptr[PyObject],
    slot: int,
    definition: TypeDefinition,
    prefix: str,
    salt: i32,
    person: i32,
    key: i32,
    digest: i32
) -> bool {
    name = "blake2b" if slot == 0 else "blake2s";
    if not add_state_owned(module, slot, name, definition.create(module)) {
        return False;
    }
    type_dict = PyType_GetDict(jacpy_binding_state_get(module, i64(slot)));
    if not type_dict {
        return False;
    }
    ok = add_type_int(type_dict, "SALT_SIZE", salt)
        and add_type_int(type_dict, "PERSON_SIZE", person)
        and add_type_int(type_dict, "MAX_KEY_SIZE", key)
        and add_type_int(type_dict, "MAX_DIGEST_SIZE", digest);
    jacpy_release(type_dict);
    return ok
        and PyModule_AddIntConstant(module, f"{prefix}_SALT_SIZE", i64(salt)) == 0
        and PyModule_AddIntConstant(module, f"{prefix}_PERSON_SIZE", i64(person)) == 0
        and PyModule_AddIntConstant(module, f"{prefix}_MAX_KEY_SIZE", i64(key)) == 0
        and PyModule_AddIntConstant(module, f"{prefix}_MAX_DIGEST_SIZE", i64(digest))
            == 0;
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    Blake2_token.bind(blake2b_type.handle);
    Blake2_token.share(blake2s_type.handle);
    if PyModule_AddIntConstant(module, "_GIL_MINSIZE", HASHLIB_GIL_MINSIZE) < 0
        or not add_blake2_type(
            module,
            0,
            blake2b_type,
            "BLAKE2B",
            HACL_HASH_BLAKE2B_SALT_BYTES,
            HACL_HASH_BLAKE2B_PERSONAL_BYTES,
            HACL_HASH_BLAKE2B_KEY_BYTES,
            HACL_HASH_BLAKE2B_OUT_BYTES
        )
        or not add_blake2_type(
            module,
            1,
            blake2s_type,
            "BLAKE2S",
            HACL_HASH_BLAKE2S_SALT_BYTES,
            HACL_HASH_BLAKE2S_PERSONAL_BYTES,
            HACL_HASH_BLAKE2S_KEY_BYTES,
            HACL_HASH_BLAKE2S_OUT_BYTES
        ) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_blake2",
         "_blake2b provides BLAKE2b for hashlib\n",
         [],
         ModuleHooks(execute=execute),
         2
     );

def:pub PyInit__blake2 -> ptr[PyObject] {
    return definition.initialize();
}
