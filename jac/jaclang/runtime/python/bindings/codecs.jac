"""The _codecs module over its generated clinic table."""

import from jaclang.runtime.python.cpython_api {
    PyObject
}
import from jaclang.runtime.python.bindings.module { ModuleDefinition }
import from jaclang.runtime.python.bindings.clinic.codecs { module_methods }

glob:priv definition = ModuleDefinition("_codecs", "", module_methods);

def:pub PyInit__codecs -> ptr[PyObject] {
    return definition.initialize();
}
