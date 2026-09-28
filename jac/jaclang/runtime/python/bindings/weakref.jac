"""The _weakref module over its generated clinic table and the weakref types."""

import from jaclang.runtime.python.cpython_api {
    PyObject,
    _PyWeakref_CallableProxyType,
    _PyWeakref_ProxyType,
    _PyWeakref_RefType
}
import from jaclang.runtime.python.bindings.module { ModuleDefinition, ModuleHooks }
import from jaclang.runtime.python.bindings.runtime_objects { export_runtime_objects }
import from jaclang.runtime.python.bindings.clinic.weakref { module_methods }

glob:priv TYPES: list[tuple[str, ptr[PyObject]]] = [
         ("ref", addressof(_PyWeakref_RefType)),
         ("ReferenceType", addressof(_PyWeakref_RefType)),
         ("ProxyType", addressof(_PyWeakref_ProxyType)),
         ("CallableProxyType", addressof(_PyWeakref_CallableProxyType))
     ];

def:priv execute(module: ptr[PyObject]) -> i32 {
    return export_runtime_objects(module, TYPES);
}

glob:priv definition = ModuleDefinition(
         "_weakref",
         "Weak-reference support module.",
         module_methods,
         ModuleHooks(execute=execute)
     );

def:pub PyInit__weakref -> ptr[PyObject] {
    return definition.initialize();
}
