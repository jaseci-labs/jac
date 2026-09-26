"""Publish interpreter-defined objects on a module by their C names.

Several modules only re-export static types and singletons the interpreter
defines as C data; jacpy_runtime_object resolves those names.
"""

import from jaclang.runtime.python.cpython_api {
    PyModule_AddObjectRef,
    PyObject,
    jacpy_runtime_object
}
import from jaclang.runtime.python.capi { object_error }

def export_runtime_objects(module: ptr[PyObject], names: list[tuple[str, str]]) -> i32 {
    for (public, symbol) in names {
        value = jacpy_runtime_object(symbol);
        if not value {
            object_error("SystemError", f"unknown runtime object {symbol}");
            return i32(-1);
        }
        if PyModule_AddObjectRef(module, public, value) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}
