"""The _bisect module: its clinic-generated functions and module definition."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module { ModuleDefinition }
import from jaclang.runtime.python.bindings.clinic.bisect { module_doc, module_methods }

glob:priv definition = ModuleDefinition("_bisect", module_doc, module_methods);

def:pub PyInit__bisect -> ptr[PyObject] {
    return definition.initialize();
}
