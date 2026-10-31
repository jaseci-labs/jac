"""The _random module: the Random type over native Mersenne Twister state."""

def:priv create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return jacpy_binding_allocate(type);
}

def:priv deallocate(instance: ptr[PyObject]) {
    jacpy_binding_free(instance);
}

glob:priv random_type = TypeDefinition(
         "_random.Random",
         random_doc,
         Random_methods,
         u64(TypeFlags.BASETYPE.value),
         TypeHooks(create=create, initialize=random_init_init, dealloc=deallocate),
         record_size=RANDOM_RECORD_SIZE
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
