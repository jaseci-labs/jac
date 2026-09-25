"""The _typing module: the identity function and the interpreter's typing types."""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module { ModuleDefinition, ModuleHooks }
import from jaclang.runtime.python.bindings.runtime_objects { export_runtime_objects }
import from jaclang.runtime.python.bindings.clinic.typing { module_methods }

glob:priv TYPES: list[tuple[str, str]] = [
         ("TypeVar", "typevar_type"),
         ("TypeVarTuple", "typevartuple_type"),
         ("ParamSpec", "paramspec_type"),
         ("ParamSpecArgs", "paramspecargs_type"),
         ("ParamSpecKwargs", "paramspeckwargs_type"),
         ("Generic", "generic_type"),
         ("TypeAliasType", "_PyTypeAlias_Type"),
         ("Union", "_PyUnion_Type"),
         ("NoDefault", "_Py_NoDefaultStruct")
     ];

def:priv execute(module: ptr[PyObject]) -> i32 {
    return export_runtime_objects(module, TYPES);
}

glob:priv definition = ModuleDefinition(
         "_typing",
         "Primitives and accelerators for the typing module.\n",
         module_methods,
         ModuleHooks(execute=execute)
     );

def:pub PyInit__typing -> ptr[PyObject] {
    return definition.initialize();
}
