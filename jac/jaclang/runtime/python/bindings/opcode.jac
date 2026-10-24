"""The _opcode module: generated clinic tables plus its two build constants."""

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PyModule_AddIntConstant(module, "ENABLE_SPECIALIZATION", ENABLE_SPECIALIZATION)
        < 0 {
        return i32(-1);
    }
    if PyModule_AddIntConstant(
        module, "ENABLE_SPECIALIZATION_FT", ENABLE_SPECIALIZATION_FT
    )
        < 0 {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_opcode",
         "Opcode support module.",
         module_methods,
         ModuleHooks(execute=execute)
     );

def:pub PyInit__opcode -> ptr[PyObject] {
    return definition.initialize();
}
