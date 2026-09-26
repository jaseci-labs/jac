"""The _types module: names for the interpreter's built-in types.

Derived from CPython 3.14.6 Modules/_typesmodule.c; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.bindings.module { ModuleDefinition, ModuleHooks }
import from jaclang.runtime.python.bindings.runtime_objects { export_runtime_objects }

glob:priv TYPES: list[tuple[str, str]] = [
         ("AsyncGeneratorType", "PyAsyncGen_Type"),
         ("BuiltinFunctionType", "PyCFunction_Type"),
         ("BuiltinMethodType", "PyCFunction_Type"),
         ("CapsuleType", "PyCapsule_Type"),
         ("CellType", "PyCell_Type"),
         ("ClassMethodDescriptorType", "PyClassMethodDescr_Type"),
         ("CodeType", "PyCode_Type"),
         ("CoroutineType", "PyCoro_Type"),
         ("EllipsisType", "PyEllipsis_Type"),
         ("FrameType", "PyFrame_Type"),
         ("FunctionType", "PyFunction_Type"),
         ("GeneratorType", "PyGen_Type"),
         ("GenericAlias", "Py_GenericAliasType"),
         ("GetSetDescriptorType", "PyGetSetDescr_Type"),
         ("LambdaType", "PyFunction_Type"),
         ("MappingProxyType", "PyDictProxy_Type"),
         ("MemberDescriptorType", "PyMemberDescr_Type"),
         ("MethodDescriptorType", "PyMethodDescr_Type"),
         ("MethodType", "PyMethod_Type"),
         ("MethodWrapperType", "_PyMethodWrapper_Type"),
         ("ModuleType", "PyModule_Type"),
         ("NoneType", "_PyNone_Type"),
         ("NotImplementedType", "_PyNotImplemented_Type"),
         ("SimpleNamespace", "_PyNamespace_Type"),
         ("TracebackType", "PyTraceBack_Type"),
         ("UnionType", "_PyUnion_Type"),
         ("WrapperDescriptorType", "PyWrapperDescr_Type")
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
