"""The _hmac module: the HMAC type, UnknownHashError and the one-shot functions
over the generated clinic glue."""

def:priv hmac_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, HMAC_token.handle);
}

def:priv hmac_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, HMAC_token.handle, visitor, context);
}

glob:priv hmac_type = TypeDefinition(
         "_hmac.HMAC",
         "",
         HMAC_methods,
         u64(
             TypeFlags.DISALLOW_INSTANTIATION.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.GC.value
         ),
         TypeHooks(repr=hmac_repr, dealloc=hmac_dealloc, traverse=hmac_traverse),
         HMAC_getset
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    HMAC_token.handle = hmac_type.handle;
    if not add_state_owned(
        module,
        UNKNOWN_HASH_ERROR,
        "UnknownHashError",
        jacpy_binding_exception("_hmac.UnknownHashError", PyExc_ValueError, "")
    )
        or not add_state_owned(module, HMAC_TYPE, "HMAC", hmac_type.create(module))
        or PyModule_AddIntConstant(module, "_GIL_MINSIZE", HASHLIB_GIL_MINSIZE) < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_hmac", "", module_methods, ModuleHooks(execute=execute), 2
     );

def:pub PyInit__hmac -> ptr[PyObject] {
    return definition.initialize();
}
