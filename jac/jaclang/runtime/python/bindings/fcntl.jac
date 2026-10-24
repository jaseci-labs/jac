"""The fcntl module: generated clinic tables and the platform constants."""

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" or len(CONSTANTS) == 0 {
        object_error(
            PyExc_ImportError,
            "fcntl has no fcntl_records/fcntl_constants for this target platform"
        );
        return i32(-1);
    }
    for (name, value) in CONSTANTS {
        if PyModule_AddIntConstant(module, name, value) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "fcntl",
         "This module performs file control and I/O control on file\ndescriptors.  It is an interface to the fcntl() and ioctl() Unix\nroutines.  File descriptors can be obtained with the fileno() method of\na file or socket object.",
         module_methods,
         ModuleHooks(execute=execute)
     );

def:pub PyInit_fcntl -> ptr[PyObject] {
    return definition.initialize();
}
