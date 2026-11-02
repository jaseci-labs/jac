glob:priv METH_NOARGS: i64 = 4;

def:priv execute(module: ptr[PyObject]) -> i32;

def:priv methods -> list[MethodDefinition];

glob:priv definition = ModuleDefinition(
         "_uuid", "", methods(), ModuleHooks(execute=execute)
     );

def:pub PyInit__uuid -> ptr[PyObject];

impl execute(module: ptr[PyObject]) -> i32 {
    if PyModule_AddIntConstant(
        module, ptr[u8]("has_uuid_generate_time_safe"), i64(HAVE_GENERATE_TIME_SAFE)
    )
        < 0
        or PyModule_AddIntConstant(
            module,
            ptr[u8]("has_stable_extractable_node"),
            i64(HAVE_GENERATE_TIME_SAFE_STABLE_MAC)
        )
            < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl methods -> list[MethodDefinition] {
    if not HAVE_UUID_HEADER {
        return [];
    }
    return [
        MethodDefinition(
            "generate_time_safe",
            MethodCallbacks(positional=py_uuid_generate_time_safe),
            "",
            METH_NOARGS
        )
    ];
}

impl PyInit__uuid -> ptr[PyObject] {
    return definition.initialize();
}
