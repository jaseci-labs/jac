"""The _types module: names for the interpreter's built-in types.

Derived from CPython 3.14.6 Modules/_typesmodule.c; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    PyAsyncGen_Type,
    PyCFunction_Type,
    PyCapsule_Type,
    PyCell_Type,
    PyClassMethodDescr_Type,
    PyCode_Type,
    PyCoro_Type,
    PyDictProxy_Type,
    PyEllipsis_Type,
    PyFrame_Type,
    PyFunction_Type,
    PyGen_Type,
    PyGetSetDescr_Type,
    PyMemberDescr_Type,
    PyMethodDescr_Type,
    PyMethod_Type,
    PyModule_Type,
    PyObject,
    PyTraceBack_Type,
    PyWrapperDescr_Type,
    Py_GenericAliasType,
    _PyMethodWrapper_Type,
    _PyNamespace_Type,
    _PyNone_Type,
    _PyNotImplemented_Type,
    _PyUnion_Type
}
import from jaclang.runtime.python.bindings.module { ModuleDefinition, ModuleHooks }
import from jaclang.runtime.python.bindings.runtime_objects { export_runtime_objects }

glob:priv TYPES: list[tuple[str, ptr[PyObject]]] = [
         ("AsyncGeneratorType", addressof(PyAsyncGen_Type)),
         ("BuiltinFunctionType", addressof(PyCFunction_Type)),
         ("BuiltinMethodType", addressof(PyCFunction_Type)),
         ("CapsuleType", addressof(PyCapsule_Type)),
         ("CellType", addressof(PyCell_Type)),
         ("ClassMethodDescriptorType", addressof(PyClassMethodDescr_Type)),
         ("CodeType", addressof(PyCode_Type)),
         ("CoroutineType", addressof(PyCoro_Type)),
         ("EllipsisType", addressof(PyEllipsis_Type)),
         ("FrameType", addressof(PyFrame_Type)),
         ("FunctionType", addressof(PyFunction_Type)),
         ("GeneratorType", addressof(PyGen_Type)),
         ("GenericAlias", addressof(Py_GenericAliasType)),
         ("GetSetDescriptorType", addressof(PyGetSetDescr_Type)),
         ("LambdaType", addressof(PyFunction_Type)),
         ("MappingProxyType", addressof(PyDictProxy_Type)),
         ("MemberDescriptorType", addressof(PyMemberDescr_Type)),
         ("MethodDescriptorType", addressof(PyMethodDescr_Type)),
         ("MethodType", addressof(PyMethod_Type)),
         ("MethodWrapperType", addressof(_PyMethodWrapper_Type)),
         ("ModuleType", addressof(PyModule_Type)),
         ("NoneType", addressof(_PyNone_Type)),
         ("NotImplementedType", addressof(_PyNotImplemented_Type)),
         ("SimpleNamespace", addressof(_PyNamespace_Type)),
         ("TracebackType", addressof(PyTraceBack_Type)),
         ("UnionType", addressof(_PyUnion_Type)),
         ("WrapperDescriptorType", addressof(PyWrapperDescr_Type))
     ];

def:priv execute(module: ptr[PyObject]) -> i32 {
    return export_runtime_objects(module, TYPES);
}

glob:priv definition = ModuleDefinition(
         "_types", "Define names for built-in types.", [], ModuleHooks(execute=execute)
     );

def:pub PyInit__types -> ptr[PyObject] {
    return definition.initialize();
}
