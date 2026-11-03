def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_heapq", module_doc, module_methods, ModuleHooks(execute=execute)
     );

def:pub PyInit__heapq -> ptr[PyObject];

impl execute(module: ptr[PyObject]) -> i32 {
    if not add_owned(module, "__about__", jacpy_unicode_from_text(__about__)) {
        return i32(-1);
    }
    return i32(0);
}

impl PyInit__heapq -> ptr[PyObject] {
    return definition.initialize();
}
