"""Publish interpreter-defined objects on a module.

Several modules only re-export static types and singletons the interpreter
defines as C data; their bindings name them by address, `addressof(PyCode_Type)`.
"""

import from jaclang.runtime.python.cpython_api { PyModule_AddObjectRef, PyObject }

def export_runtime_objects(
    module: ptr[PyObject], objects: list[tuple[str, ptr[PyObject]]]
) -> i32 {
    for (public, value) in objects {
        if PyModule_AddObjectRef(module, public, value) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}
