"""The _weakref module over its generated clinic table and the weakref types."""

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
