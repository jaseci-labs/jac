"""The _posixshmem module: shm_open() and shm_unlink() from the generated clinic glue."""

import from jaclang.runtime.python.cpython_api {
    PyObject
}
import from jaclang.runtime.python.bindings.module { ModuleDefinition }
import from jaclang.runtime.python.bindings.clinic.posixshmem { module_methods }

glob:priv definition = ModuleDefinition(
         "_posixshmem", "POSIX shared memory module", module_methods
     );

def:pub PyInit__posixshmem -> ptr[PyObject] {
    return definition.initialize();
}
