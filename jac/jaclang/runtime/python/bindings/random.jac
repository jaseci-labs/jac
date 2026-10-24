"""The _random module: the Random type over native Mersenne Twister state."""

# PyType_GenericNew, with the instance's native generator state.
def:priv create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if instance == 0 {
        return NULL;
    }
    if jacpy_binding_native_set(instance, random_type.handle, jacpy_random_new()) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def:priv deallocate(instance: ptr[PyObject]) {
    jacpy_binding_native_clear(instance, random_type.handle);
    jacpy_binding_free(instance);
}

glob:priv random_type = TypeDefinition(
         "_random.Random",
         random_doc,
         Random_methods,
         u64(TypeFlags.BASETYPE.value),
         TypeHooks(create=create, initialize=random_init_init, dealloc=deallocate)
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    Random_token.handle = random_type.handle;
    return i32(0)
        if add_state_owned(module, 0, "Random", random_type.create(module))
        else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "_random", module_doc, [], ModuleHooks(execute=execute), 1
     );

def:pub PyInit__random -> ptr[PyObject] {
    return definition.initialize();
}
