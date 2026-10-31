"""The Argument Clinic signatures of marshal.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/marshal.jac from them. Taken from
CPython 3.14.6 Python/marshal.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="marshal",
         version="3.14.6",
         sources=["Python/marshal.c"],
         functions=[
             Function(
                 name="dump",
                 full_name="marshal.dump",
                 c_basename="marshal_dump",
                 docstring="dump($module, value, file, version=version, /, *, allow_code=True)\n"
                 "--\n"
                 "\n"
                 "Write the value on the open file.\n"
                 "\n"
                 "  value\n"
                 "    Must be a supported type.\n"
                 "  file\n"
                 "    Must be a writeable binary file.\n"
                 "  version\n"
                 "    Indicates the data format that dump should use.\n"
                 "  allow_code\n"
                 "    Allow to write code objects.\n"
                 "\n"
                 "If the value has (or contains an object that has) an unsupported type, a\n"
                 "ValueError exception is raised - but garbage data will also be written\n"
                 "to the file. The object will not be properly read back by load().",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="file", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="version",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="Py_MARSHAL_VERSION"
                     ),
                     Parameter(
                         name="allow_code",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="load",
                 full_name="marshal.load",
                 c_basename="marshal_load",
                 docstring="load($module, file, /, *, allow_code=True)\n"
                 "--\n"
                 "\n"
                 "Read one value from the open file and return it.\n"
                 "\n"
                 "  file\n"
                 "    Must be readable binary file.\n"
                 "  allow_code\n"
                 "    Allow to load code objects.\n"
                 "\n"
                 "If no valid value is read (e.g. because the data has a different Python\n"
                 "version's incompatible marshal format), raise EOFError, ValueError or\n"
                 "TypeError.\n"
                 "\n"
                 "Note: If an object containing an unsupported type was marshalled with\n"
                 "dump(), load() will substitute None for the unmarshallable type.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="file", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="allow_code",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="dumps",
                 full_name="marshal.dumps",
                 c_basename="marshal_dumps",
                 docstring="dumps($module, value, version=version, /, *, allow_code=True)\n"
                 "--\n"
                 "\n"
                 "Return the bytes object that would be written to a file by dump(value, file).\n"
                 "\n"
                 "  value\n"
                 "    Must be a supported type.\n"
                 "  version\n"
                 "    Indicates the data format that dumps should use.\n"
                 "  allow_code\n"
                 "    Allow to write code objects.\n"
                 "\n"
                 "Raise a ValueError exception if value has (or contains an object that\n"
                 "has) an unsupported type.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="version",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="Py_MARSHAL_VERSION"
                     ),
                     Parameter(
                         name="allow_code",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="loads",
                 full_name="marshal.loads",
                 c_basename="marshal_loads",
                 docstring="loads($module, bytes, /, *, allow_code=True)\n"
                 "--\n"
                 "\n"
                 "Convert the bytes-like object to a value.\n"
                 "\n"
                 "  allow_code\n"
                 "    Allow to load code objects.\n"
                 "\n"
                 "If no valid value is found, raise EOFError, ValueError or TypeError.\n"
                 "Extra bytes in the input are ignored.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="bytes",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="allow_code",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ],
         docs={
             "module_doc": "This module contains functions that can read and write Python values in\n"
             "a binary format. The format is specific to Python, but independent of\n"
             "machine architecture issues.\n"
             "\n"
             "Not all Python object types are supported; in general, only objects\n"
             "whose value is independent from a particular invocation of Python can be\n"
             "written and read by this module. The following types are supported:\n"
             "None, integers, floating-point numbers, strings, bytes, bytearrays,\n"
             "tuples, lists, sets, dictionaries, and code objects, where it\n"
             "should be understood that tuples, lists and dictionaries are only\n"
             "supported as long as the values contained therein are themselves\n"
             "supported; and recursive lists and dictionaries should not be written\n"
             "(they will cause infinite loops).\n"
             "\n"
             "Variables:\n"
             "\n"
             "version -- indicates the format that the module uses. Version 0 is the\n"
             "    historical format, version 1 shares interned strings and version 2\n"
             "    uses a binary format for floating-point numbers.\n"
             "    Version 3 shares common object references (New in version 3.4).\n"
             "\n"
             "Functions:\n"
             "\n"
             "dump() -- write value to a file\n"
             "load() -- read value from a file\n"
             "dumps() -- marshal value as a bytes object\n"
             "loads() -- read value from a bytes-like object"
         }
     );
