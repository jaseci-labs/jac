def:priv data_dealloc(instance: ptr[PyObject]);

def:priv data_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def:priv data_clear(instance: ptr[PyObject]) -> i32;

glob:priv data_type = TypeDefinition(
         "_abc._abc_data",
         "Internal state held by ABC machinery.",
         [],
         u64(TypeFlags.GC.value),
         TypeHooks(
             create=abc_data_new,
             dealloc=data_dealloc,
             traverse=data_traverse,
             clear=data_clear
         )
     );

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_abc",
         "Module contains faster C implementation of abc.ABCMeta",
         module_methods,
         ModuleHooks(execute=execute),
         len(STATE_NAMES) + 1
     );

def:pub PyInit__abc -> ptr[PyObject];

impl data_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, abc_data_token.handle);
}

impl data_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, abc_data_token.handle, visitor, context);
}

impl data_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, abc_data_token.handle);
}

impl execute(module: ptr[PyObject]) -> i32 {
    abc_data_token.handle = data_type.handle;
    jacpy_binding_module_native_set(module, AbcModuleState());
    type = data_type.create(module);
    if not type {
        return i32(-1);
    }
    jacpy_binding_state_set(module, i64(DATA_TYPE), type);
    jacpy_release(type);
    for index in range(len(STATE_NAMES)) {
        name = jacpy_unicode_intern_text(STATE_NAMES[index]);
        if not name {
            return i32(-1);
        }
        jacpy_binding_state_set(module, i64(index + 1), name);
        jacpy_release(name);
    }
    return i32(0);
}

impl PyInit__abc -> ptr[PyObject] {
    return definition.initialize();
}
