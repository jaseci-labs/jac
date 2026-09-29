"""The _heapq module: its clinic-generated functions and __about__."""

import from jaclang.runtime.python.cpython_api { PyObject, PyUnicode_FromString }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_owned
}
import from jaclang.runtime.python.bindings.clinic.heapq {
    __about__,
    module_doc,
    module_methods
}

# heapq_exec(): the module's __about__ text.
def:priv execute(module: ptr[PyObject]) -> i32 {
    if not add_owned(module, "__about__", PyUnicode_FromString(__about__)) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_heapq", module_doc, module_methods, ModuleHooks(execute=execute)
     );

def:pub PyInit__heapq -> ptr[PyObject] {
    return definition.initialize();
}
