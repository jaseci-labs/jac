"""The _sysconfig module over its generated clinic table."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module { ModuleDefinition }
import from jaclang.runtime.python.bindings.clinic.sysconfig { module_methods }

glob:priv definition = ModuleDefinition(
         "_sysconfig", "A helper for the sysconfig module.", module_methods
     );

def:pub PyInit__sysconfig -> ptr[PyObject] {
    return definition.initialize();
}
