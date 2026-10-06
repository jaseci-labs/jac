"""The binascii module: its clinic-generated functions and exception types."""

import from jaclang.runtime.python.cpython_api { NULL, PyExc_ValueError, PyObject }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_exception
}
import from jaclang.runtime.python.bindings.clinic.binascii {
    doc_binascii,
    module_methods
}

# binascii_exec(): Error (a ValueError) and Incomplete, in state slots 0 and 1.
def:priv execute(module: ptr[PyObject]) -> i32 {
    if not add_state_owned(
        module,
        0,
        "Error",
        jacpy_binding_exception("binascii.Error", PyExc_ValueError, "")
    ) {
        return i32(-1);
    }
    if not add_state_owned(
        module,
        1,
        "Incomplete",
        jacpy_binding_exception("binascii.Incomplete", NULL, "")
    ) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "binascii", doc_binascii, module_methods, ModuleHooks(execute=execute), 2
     );

def:pub PyInit_binascii -> ptr[PyObject] {
    return definition.initialize();
}
