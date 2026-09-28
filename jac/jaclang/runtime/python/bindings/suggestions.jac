"""The _suggestions module over its generated clinic table."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module { ModuleDefinition }
import from jaclang.runtime.python.bindings.clinic.suggestions { module_methods }

glob:priv definition = ModuleDefinition("_suggestions", "", module_methods);

def:pub PyInit__suggestions -> ptr[PyObject] {
    return definition.initialize();
}
