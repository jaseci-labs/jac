"""The cmath module: its clinic-generated functions and constants."""

import from jaclang.runtime.python.cpython_api {
    PyComplex_FromDoubles,
    PyFloat_FromDouble,
    PyObject
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_owned
}
import from jaclang.runtime.python.bindings.clinic.cmath { module_doc, module_methods }

# cmath_exec(): pi, e, tau, inf, infj, nan and nanj.
def:priv execute(module: ptr[PyObject]) -> i32 {
    names = ["pi", "e", "tau", "inf", "nan"];
    values = [
        3.14159265358979323846,
        2.71828182845904523536,
        6.28318530717958647693,
        float("inf"),
        float("nan")
    ];
    for i in range(len(names)) {
        if not add_owned(module, names[i], PyFloat_FromDouble(values[i])) {
            return i32(-1);
        }
    }
    if not add_owned(module, "infj", PyComplex_FromDoubles(0.0, float("inf"))) {
        return i32(-1);
    }
    if not add_owned(module, "nanj", PyComplex_FromDoubles(0.0, float("nan"))) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "cmath", module_doc, module_methods, ModuleHooks(execute=execute)
     );

def:pub PyInit_cmath -> ptr[PyObject] {
    return definition.initialize();
}
