def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_opcode",
         "Opcode support module.",
         module_methods,
         ModuleHooks(execute=execute)
     );

def:pub PyInit__opcode -> ptr[PyObject];

impl execute(module: ptr[PyObject]) -> i32 {
    if PyModule_AddIntConstant(
        module, ptr[u8]("ENABLE_SPECIALIZATION"), ENABLE_SPECIALIZATION
    )
        < 0 {
        return i32(-1);
    }
    if PyModule_AddIntConstant(
        module, ptr[u8]("ENABLE_SPECIALIZATION_FT"), ENABLE_SPECIALIZATION_FT
    )
        < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl PyInit__opcode -> ptr[PyObject] {
    return definition.initialize();
}
