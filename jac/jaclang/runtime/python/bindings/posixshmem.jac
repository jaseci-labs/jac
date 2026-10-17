"""The _posixshmem module: shm_open() and shm_unlink() from the generated clinic glue."""

glob:priv definition = ModuleDefinition(
         "_posixshmem", "POSIX shared memory module", module_methods
     );

def:pub PyInit__posixshmem -> ptr[PyObject] {
    return definition.initialize();
}
