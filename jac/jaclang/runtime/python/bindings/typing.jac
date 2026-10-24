"""The _typing module: the identity function and the interpreter's typing types.

Derived from CPython 3.14.6 Modules/_typingmodule.c; see ../LICENSE.cpython.
"""

# Positions in jacpy_typing_types(), the interpreter's cached typing types in
# the declaration order of struct _Py_interp_cached_objects.
glob:priv CACHED: list[tuple[str, int]] = [
         ("TypeVar", 1),
         ("TypeVarTuple", 2),
         ("ParamSpec", 3),
         ("ParamSpecArgs", 4),
         ("ParamSpecKwargs", 5),
         ("Generic", 0)
     ];

def:priv execute(module: ptr[PyObject]) -> i32 {
    cached = jacpy_typing_types().view(6);
    objects: list[tuple[str, ptr[PyObject]]] = [];
    for (name, index) in CACHED {
        objects.append((name, cached[index]));
    }
    objects.append(("TypeAliasType", addressof(_PyTypeAlias_Type)));
    objects.append(("Union", addressof(_PyUnion_Type)));
    objects.append(("NoDefault", addressof(_Py_NoDefaultStruct)));
    return export_runtime_objects(module, objects);
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
