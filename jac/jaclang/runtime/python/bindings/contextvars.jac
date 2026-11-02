glob:priv METH_NOARGS: i64 = 4;

def:priv _contextvars_copy_context(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _contextvars_exec(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_contextvars",
         "Context Variables",
         [
             MethodDefinition(
                 "copy_context",
                 MethodCallbacks(positional=_contextvars_copy_context),
                 "copy_context($module, /)\n--\n\n",
                 METH_NOARGS
             )
         ],
         ModuleHooks(execute=_contextvars_exec)
     );

def:pub PyInit__contextvars -> ptr[PyObject];

impl _contextvars_copy_context(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _contextvars_copy_context_impl(module);
}

impl _contextvars_exec(module: ptr[PyObject]) -> i32 {
    if PyModule_AddType(module, ptr[PyObject](addressof(PyContext_Type))) < 0 {
        return i32(-1);
    }
    if PyModule_AddType(module, ptr[PyObject](addressof(PyContextVar_Type))) < 0 {
        return i32(-1);
    }
    if PyModule_AddType(module, ptr[PyObject](addressof(PyContextToken_Type))) < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl PyInit__contextvars -> ptr[PyObject] {
    return definition.initialize();
}
