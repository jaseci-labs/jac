"""The _tracemalloc module over its generated clinic table."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module { ModuleDefinition }
import from jaclang.runtime.python.bindings.clinic.tracemalloc { module_methods }

glob:priv definition = ModuleDefinition(
         "_tracemalloc",
         "Debug module to trace memory blocks allocated by Python.",
         module_methods
     );

def:pub PyInit__tracemalloc -> ptr[PyObject] {
    return definition.initialize();
}
