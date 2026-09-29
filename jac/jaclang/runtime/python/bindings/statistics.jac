"""The _statistics module: its clinic-generated function."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module { ModuleDefinition }
import from jaclang.runtime.python.bindings.clinic.statistics {
    module_methods,
    statistics_doc
}

glob:priv definition = ModuleDefinition("_statistics", statistics_doc, module_methods);

def:pub PyInit__statistics -> ptr[PyObject] {
    return definition.initialize();
}
