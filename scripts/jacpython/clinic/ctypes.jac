"""The Argument Clinic signatures of _ctypes.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/ctypes.jac from them. Taken from
the C sources it replaces (Modules/_ctypes/_ctypes.c, Modules/_ctypes/callbacks.c, Modules/_ctypes/callproc.c, Modules/_ctypes/stgdict.c, Modules/_ctypes/cfield.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_ctypes",
         version="3.14.6",
         sources=[
             "Modules/_ctypes/_ctypes.c",
             "Modules/_ctypes/callbacks.c",
             "Modules/_ctypes/callproc.c",
             "Modules/_ctypes/stgdict.c",
             "Modules/_ctypes/cfield.c"
         ],
         classes={
             "CFuncPtr": "PyCFuncPtrObject *",
             "CType_Type": "PyObject *",
             "CDataType": "PyObject *",
             "PyCPointerType": "PyObject *",
             "PyCArrayType_Type": "CDataObject *",
             "PyCSimpleType": "PyObject *",
             "c_wchar_p": "PyObject *",
             "c_char_p": "PyObject *",
             "c_void_p": "PyObject *",
             "PyCData": "PyObject *",
             "Simple": "CDataObject *",
             "CField": "PyObject *"
         },
         functions=[
             Function(
                 name="errcheck",
                 full_name="_ctypes.CFuncPtr.errcheck",
                 c_basename="_ctypes_CFuncPtr_errcheck",
                 kind="SETTER",
                 cls="CFuncPtr",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="errcheck",
                 full_name="_ctypes.CFuncPtr.errcheck",
                 c_basename="_ctypes_CFuncPtr_errcheck",
                 kind="GETTER",
                 cls="CFuncPtr",
                 docstring="a function to check for errors",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="restype",
                 full_name="_ctypes.CFuncPtr.restype",
                 c_basename="_ctypes_CFuncPtr_restype",
                 kind="SETTER",
                 cls="CFuncPtr",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="restype",
                 full_name="_ctypes.CFuncPtr.restype",
                 c_basename="_ctypes_CFuncPtr_restype",
                 kind="GETTER",
                 cls="CFuncPtr",
                 docstring="specify the result type",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="argtypes",
                 full_name="_ctypes.CFuncPtr.argtypes",
                 c_basename="_ctypes_CFuncPtr_argtypes",
                 kind="SETTER",
                 cls="CFuncPtr",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="argtypes",
                 full_name="_ctypes.CFuncPtr.argtypes",
                 c_basename="_ctypes_CFuncPtr_argtypes",
                 kind="GETTER",
                 cls="CFuncPtr",
                 docstring="specify the argument types",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="__sizeof__",
                 full_name="_ctypes.CType_Type.__sizeof__",
                 c_basename="_ctypes_CType_Type___sizeof__",
                 cls="CType_Type",
                 docstring="__sizeof__($self, /)\n"
                 "--\n"
                 "\n"
                 "Return memory consumption of the type object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="from_address",
                 full_name="_ctypes.CDataType.from_address",
                 c_basename="CDataType_from_address",
                 cls="CDataType",
                 docstring="from_address($self, value, /)\n"
                 "--\n"
                 "\n"
                 "C.from_address(integer) -> C instance\n"
                 "\n"
                 "Access a C instance at the specified address.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="from_buffer",
                 full_name="_ctypes.CDataType.from_buffer",
                 c_basename="CDataType_from_buffer",
                 cls="CDataType",
                 docstring="from_buffer($self, obj, offset=0, /)\n"
                 "--\n"
                 "\n"
                 "C.from_buffer(object, offset=0) -> C instance\n"
                 "\n"
                 "Create a C instance from a writeable buffer.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="obj", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="from_buffer_copy",
                 full_name="_ctypes.CDataType.from_buffer_copy",
                 c_basename="CDataType_from_buffer_copy",
                 cls="CDataType",
                 docstring="from_buffer_copy($self, buffer, offset=0, /)\n"
                 "--\n"
                 "\n"
                 "C.from_buffer_copy(object, offset=0) -> C instance\n"
                 "\n"
                 "Create a C instance from a readable buffer.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="buffer",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="in_dll",
                 full_name="_ctypes.CDataType.in_dll",
                 c_basename="CDataType_in_dll",
                 cls="CDataType",
                 docstring="in_dll($self, dll, name, /)\n"
                 "--\n"
                 "\n"
                 "C.in_dll(dll, name) -> C instance\n"
                 "\n"
                 "Access a C instance in a dll.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="dll", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="from_param",
                 full_name="_ctypes.CDataType.from_param",
                 c_basename="CDataType_from_param",
                 cls="CDataType",
                 docstring="from_param($self, value, /)\n"
                 "--\n"
                 "\n"
                 "Convert a Python object into a function call parameter.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="set_type",
                 full_name="_ctypes.PyCPointerType.set_type",
                 c_basename="PyCPointerType_set_type",
                 cls="PyCPointerType",
                 docstring="set_type($self, type, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="type", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="from_param",
                 full_name="_ctypes.PyCPointerType.from_param",
                 c_basename="PyCPointerType_from_param",
                 cls="PyCPointerType",
                 docstring="from_param($self, value, /)\n"
                 "--\n"
                 "\n"
                 "Convert a Python object into a function call parameter.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="raw",
                 full_name="_ctypes.PyCArrayType_Type.raw",
                 c_basename="_ctypes_PyCArrayType_Type_raw",
                 kind="SETTER",
                 cls="PyCArrayType_Type",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="raw",
                 full_name="_ctypes.PyCArrayType_Type.raw",
                 c_basename="_ctypes_PyCArrayType_Type_raw",
                 kind="GETTER",
                 cls="PyCArrayType_Type",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="value",
                 full_name="_ctypes.PyCArrayType_Type.value",
                 c_basename="_ctypes_PyCArrayType_Type_value",
                 kind="GETTER",
                 cls="PyCArrayType_Type",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="value",
                 full_name="_ctypes.PyCArrayType_Type.value",
                 c_basename="_ctypes_PyCArrayType_Type_value",
                 kind="SETTER",
                 cls="PyCArrayType_Type",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="from_param",
                 full_name="_ctypes.PyCSimpleType.from_param",
                 c_basename="PyCSimpleType_from_param",
                 cls="PyCSimpleType",
                 docstring="from_param($self, value, /)\n"
                 "--\n"
                 "\n"
                 "Convert a Python object into a function call parameter.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="from_param",
                 full_name="_ctypes.c_wchar_p.from_param",
                 c_basename="c_wchar_p_from_param",
                 cls="c_wchar_p",
                 docstring="from_param($self, value, /)\n" "--",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="from_param",
                 full_name="_ctypes.c_char_p.from_param",
                 c_basename="c_char_p_from_param",
                 cls="c_char_p",
                 docstring="from_param($self, value, /)\n" "--",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="from_param",
                 full_name="_ctypes.c_void_p.from_param",
                 c_basename="c_void_p_from_param",
                 cls="c_void_p",
                 docstring="from_param($self, value, /)\n" "--",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__reduce__",
                 full_name="_ctypes.PyCData.__reduce__",
                 c_basename="_ctypes_PyCData___reduce__",
                 cls="PyCData",
                 docstring="__reduce__($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="myself",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="__setstate__",
                 full_name="_ctypes.PyCData.__setstate__",
                 c_basename="_ctypes_PyCData___setstate__",
                 cls="PyCData",
                 docstring="__setstate__($self, dict, data, /)\n" "--",
                 params=[
                     Parameter(
                         name="myself",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="dict",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyDict_Type"
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s#"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_FORMAT",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="__ctypes_from_outparam__",
                 full_name="_ctypes.PyCData.__ctypes_from_outparam__",
                 c_basename="_ctypes_PyCData___ctypes_from_outparam__",
                 cls="PyCData",
                 docstring="__ctypes_from_outparam__($self, /)\n"
                 "--\n"
                 "\n"
                 "default __ctypes_from_outparam__ method returns self.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="value",
                 full_name="_ctypes.Simple.value",
                 c_basename="_ctypes_Simple_value",
                 kind="SETTER",
                 cls="Simple",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="value",
                 full_name="_ctypes.Simple.value",
                 c_basename="_ctypes_Simple_value",
                 kind="GETTER",
                 cls="Simple",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="__ctypes_from_outparam__",
                 full_name="_ctypes.Simple.__ctypes_from_outparam__",
                 c_basename="Simple_from_outparm",
                 cls="Simple",
                 docstring="__ctypes_from_outparam__($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="sizeof",
                 full_name="_ctypes.sizeof",
                 c_basename="_ctypes_sizeof",
                 docstring="sizeof($module, obj, /)\n"
                 "--\n"
                 "\n"
                 "Return the size in bytes of a C instance.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="obj", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="byref",
                 full_name="_ctypes.byref",
                 c_basename="_ctypes_byref",
                 docstring="byref($module, obj, offset=0, /)\n"
                 "--\n"
                 "\n"
                 "Return a pointer lookalike to a C instance, only usable as function argument.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="obj",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="clinic_state()->PyCData_Type"
                     ),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="addressof",
                 full_name="_ctypes.addressof",
                 c_basename="_ctypes_addressof",
                 docstring="addressof($module, obj, /)\n"
                 "--\n"
                 "\n"
                 "Return the address of the C instance internal buffer",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="obj",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="clinic_state()->PyCData_Type"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="resize",
                 full_name="_ctypes.resize",
                 c_basename="_ctypes_resize",
                 docstring="resize($module, obj, size, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="obj",
                         kind="POSITIONAL_ONLY",
                         type="CDataObject *",
                         format_unit="O!",
                         subclass_of="clinic_state()->PyCData_Type"
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="__new__",
                 full_name="_ctypes.CField.__new__",
                 c_basename="PyCField_new",
                 kind="METHOD_NEW",
                 cls="CField",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="name",
                         kind="KEYWORD_ONLY",
                         format_unit="O!",
                         subclass_of="&PyUnicode_Type"
                     ),
                     Parameter(name="type", kind="KEYWORD_ONLY", format_unit="O"),
                     Parameter(
                         name="byte_size",
                         kind="KEYWORD_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="byte_offset",
                         kind="KEYWORD_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="index",
                         kind="KEYWORD_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="_internal_use",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     ),
                     Parameter(
                         name="bit_size",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="bit_offset",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_kw_only=6
             )
         ],
         docs={
             "dictremover_doc": "deletes a key from a dictionary",
             "array_doc": "Abstract base class for arrays.\n"
             "\n"
             "The recommended way to create concrete array types is by multiplying any\n"
             "ctypes data type with a non-negative integer. Alternatively, you can subclass\n"
             "this type and define _length_ and _type_ class variables. Array elements can\n"
             "be read and written using standard subscript and slice accesses for slice\n"
             "reads, the resulting object is not itself an Array.",
             "_ctypes__doc__": "Create and manipulate C compatible data types in Python.",
             "comerror_doc": "Raised when a COM method call failed.",
             "format_error_doc": "FormatError([integer]) -> string\n"
             "\n"
             "Convert a win32 error code into a string. If the error code is not\n"
             "given, the return value of a call to GetLastError() is used.\n",
             "load_library_doc": "LoadLibrary(name, load_flags) -> handle\n"
             "\n"
             "Load an executable (usually a DLL), and return a handle to it.\n"
             "The handle may be used to locate exported functions in this\n"
             "module. load_flags are as defined for LoadLibraryEx in the\n"
             "Windows API.\n",
             "free_library_doc": "FreeLibrary(handle) -> void\n"
             "\n"
             "Free the handle of an executable previously loaded by LoadLibrary.\n",
             "copy_com_pointer_doc": "CopyComPointer(src, dst) -> HRESULT value\n",
             "alignment_doc": "alignment(C type) -> integer\n"
             "alignment(C instance) -> integer\n"
             "Return the alignment requirements of a C instance",
             "ctype_getsets___pointer_type___doc": "pointer type",
             "WCharArray_getsets_value_doc": "string value",
             "PyCData_members__b_base__doc": "the base object",
             "PyCData_members__b_needsfree__doc": "whether the object owns the memory or not",
             "PyCData_members__objects_doc": "internal objects tree (NEVER CHANGE THIS OBJECT!)",
             "Array_methods___class_getitem___doc": "Arrays are generic over the type of their elements",
             "Pointer_getsets_contents_doc": "the object this pointer points to (read-write)",
             "PyCArgType_members__obj_doc": "the wrapped object",
             "_ctypes_module_methods_buffer_info_doc": "Return buffer interface information",
             "_ctypes_module_methods_dlopen_doc": "dlopen(name, flag={RTLD_GLOBAL|RTLD_LOCAL}) open a shared library",
             "_ctypes_module_methods_dlclose_doc": "dlclose a library",
             "_ctypes_module_methods_dlsym_doc": "find symbol in shared library",
             "_ctypes_module_methods__dyld_shared_cache_contains_path_doc": "check if path is in the shared cache",
             "PyCField_getset_size_doc": "size in bytes of this field. For bitfields, this is a legacy packed value; use byte_size instead",
             "PyCField_getset_bit_size_doc": "size of this field in bits",
             "PyCField_getset_is_bitfield_doc": "true if this is a bitfield",
             "PyCField_getset_is_anonymous_doc": "true if this field is anonymous",
             "PyCField_members_name_doc": "name of this field",
             "PyCField_members_type_doc": "type of this field",
             "PyCField_members_offset_doc": "offset in bytes of this field (same as byte_offset)",
             "PyCField_members_byte_offset_doc": "offset in bytes of this field. For bitfields: excludes bit_offset.",
             "PyCField_members_byte_size_doc": "size of this field in bytes",
             "PyCField_members_bit_offset_doc": "additional offset in bits (relative to byte_offset); zero for non-bitfields"
         }
     );
