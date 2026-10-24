"""The _posixsubprocess module: the generated fork_exec() clinic table."""

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" or len(CONSTANTS) == 0 {
        object_error(
            PyExc_ImportError,
            "_posixsubprocess has no posixsubprocess_platform/posixsubprocess_constants for this target platform"
        );
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_posixsubprocess",
         "A POSIX helper for the subprocess module.",
         module_methods,
         ModuleHooks(execute=execute)
     );

def:pub PyInit__posixsubprocess -> ptr[PyObject] {
    return definition.initialize();
}
