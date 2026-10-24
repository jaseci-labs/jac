"""The _sha1 module: the sha1 type over its generated clinic glue."""

def:priv sha1_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, SHA1Type_token.handle);
}

def:priv sha1_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, SHA1Type_token.handle, visitor, context);
}

def:priv get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(SHA1_BLOCKSIZE);
}

def:priv get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyUnicode_FromString("sha1");
}

def:priv get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(SHA1_DIGESTSIZE);
}

glob:priv sha1_type = TypeDefinition(
         "_sha1.sha1",
         "",
         SHA1Type_methods,
         u64(
             TypeFlags.DISALLOW_INSTANTIATION.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.GC.value
         ),
         TypeHooks(dealloc=sha1_dealloc, traverse=sha1_traverse),
         [
             PropertyDefinition("block_size", PropertyCallbacks(read=get_block_size)),
             PropertyDefinition("name", PropertyCallbacks(read=get_name)),
             PropertyDefinition("digest_size", PropertyCallbacks(read=get_digest_size))
         ]
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    SHA1Type_token.handle = sha1_type.handle;
    if not add_state_owned(module, 0, "SHA1Type", sha1_type.create(module))
        or PyModule_AddIntConstant(module, "_GIL_MINSIZE", HASHLIB_GIL_MINSIZE) < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_sha1", "", module_methods, ModuleHooks(execute=execute), 1
     );

def:pub PyInit__sha1 -> ptr[PyObject] {
    return definition.initialize();
}
