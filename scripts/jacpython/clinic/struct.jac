"""The Argument Clinic signatures of _struct.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/struct.jac from them. Taken from
CPython 3.14.6 Modules/_struct.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_struct",
         version="3.14.6",
         sources=["Modules/_struct.c"],
         classes={"Struct": "PyStructObject *"},
         functions=[
             Function(
                 name="_clearcache",
                 full_name="_clearcache",
                 c_basename="_clearcache",
                 docstring="_clearcache($module, /)\n"
                 "--\n"
                 "\n"
                 "Clear the internal cache.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="calcsize",
                 full_name="calcsize",
                 c_basename="calcsize",
                 docstring="calcsize($module, format, /)\n"
                 "--\n"
                 "\n"
                 "Return size in bytes of the struct described by the format string.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="format",
                         kind="POSITIONAL_ONLY",
                         converter="cache_struct",
                         type="PyStructObject *",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="cache_struct_converter",
                         takes_module=True,
                         releases=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="unpack",
                 full_name="unpack",
                 c_basename="unpack",
                 docstring="unpack($module, format, buffer, /)\n"
                 "--\n"
                 "\n"
                 "Return a tuple containing values unpacked according to the format string.\n"
                 "\n"
                 "The buffer's size in bytes must be calcsize(format).\n"
                 "\n"
                 "See help(struct) for more on format strings.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="format",
                         kind="POSITIONAL_ONLY",
                         converter="cache_struct",
                         type="PyStructObject *",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="cache_struct_converter",
                         takes_module=True,
                         releases=True
                     ),
                     Parameter(
                         name="buffer",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="unpack_from",
                 full_name="unpack_from",
                 c_basename="unpack_from",
                 docstring="unpack_from($module, format, /, buffer, offset=0)\n"
                 "--\n"
                 "\n"
                 "Return a tuple containing values unpacked according to the format string.\n"
                 "\n"
                 "The buffer's size, minus offset, must be at least calcsize(format).\n"
                 "\n"
                 "See help(struct) for more on format strings.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="format",
                         kind="POSITIONAL_ONLY",
                         converter="cache_struct",
                         type="PyStructObject *",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="cache_struct_converter",
                         takes_module=True,
                         releases=True
                     ),
                     Parameter(
                         name="buffer",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="offset",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3,
                 pos_only=1
             ),
             Function(
                 name="iter_unpack",
                 full_name="iter_unpack",
                 c_basename="iter_unpack",
                 docstring="iter_unpack($module, format, buffer, /)\n"
                 "--\n"
                 "\n"
                 "Return an iterator yielding tuples unpacked from the given bytes.\n"
                 "\n"
                 "The bytes are unpacked according to the format string, like\n"
                 "a repeated invocation of unpack_from().\n"
                 "\n"
                 "Requires that the bytes length be a multiple of the format struct size.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="format",
                         kind="POSITIONAL_ONLY",
                         converter="cache_struct",
                         type="PyStructObject *",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="cache_struct_converter",
                         takes_module=True,
                         releases=True
                     ),
                     Parameter(name="buffer", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="__init__",
                 full_name="Struct.__init__",
                 c_basename="Struct___init__",
                 kind="METHOD_INIT",
                 cls="Struct",
                 docstring="Struct(format)\n"
                 "--\n"
                 "\n"
                 "Create a compiled struct object.\n"
                 "\n"
                 "Return a new Struct object which writes and reads binary data according to\n"
                 "the format string.\n"
                 "\n"
                 "See help(struct) for more on format strings.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="format", format_unit="O")
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="unpack",
                 full_name="Struct.unpack",
                 c_basename="Struct_unpack",
                 cls="Struct",
                 docstring="unpack($self, buffer, /)\n"
                 "--\n"
                 "\n"
                 "Return a tuple containing unpacked values.\n"
                 "\n"
                 "Unpack according to the format string Struct.format. The buffer's size\n"
                 "in bytes must be Struct.size.\n"
                 "\n"
                 "See help(struct) for more on format strings.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="buffer",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="unpack_from",
                 full_name="Struct.unpack_from",
                 c_basename="Struct_unpack_from",
                 cls="Struct",
                 docstring="unpack_from($self, /, buffer, offset=0)\n"
                 "--\n"
                 "\n"
                 "Return a tuple containing unpacked values.\n"
                 "\n"
                 "Values are unpacked according to the format string Struct.format.\n"
                 "\n"
                 "The buffer's size in bytes, starting at position offset, must be\n"
                 "at least Struct.size.\n"
                 "\n"
                 "See help(struct) for more on format strings.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="buffer",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="offset",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="iter_unpack",
                 full_name="Struct.iter_unpack",
                 c_basename="Struct_iter_unpack",
                 cls="Struct",
                 docstring="iter_unpack($self, buffer, /)\n"
                 "--\n"
                 "\n"
                 "Return an iterator yielding tuples.\n"
                 "\n"
                 "Tuples are unpacked from the given bytes source, like a repeated\n"
                 "invocation of unpack_from().\n"
                 "\n"
                 "Requires that the bytes length be a multiple of the struct size.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="buffer", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ],
         docs={
             "s_pack__doc__": "S.pack(v1, v2, ...) -> bytes\n"
             "\n"
             "Return a bytes object containing values v1, v2, ... packed according\n"
             "to the format string S.format.  See help(struct) for more on format\n"
             "strings.",
             "s_pack_into__doc__": "S.pack_into(buffer, offset, v1, v2, ...)\n"
             "\n"
             "Pack the values v1, v2, ... according to the format string S.format\n"
             "and write the packed bytes into the writable buffer buf starting at\n"
             "offset.  Note that the offset is a required argument.  See\n"
             "help(struct) for more on format strings.",
             "s_sizeof__doc__": "S.__sizeof__() -> size of S in memory, in bytes",
             "s__doc__": "Struct(fmt) --> compiled struct object\n\n",
             "pack_doc": "pack(format, v1, v2, ...) -> bytes\n"
             "\n"
             "Return a bytes object containing the values v1, v2, ... packed according\n"
             "to the format string.  See help(struct) for more on format strings.",
             "pack_into_doc": "pack_into(format, buffer, offset, v1, v2, ...)\n"
             "\n"
             "Pack the values v1, v2, ... according to the format string and write\n"
             "the packed bytes into the writable buffer buf starting at offset.  Note\n"
             "that the offset is a required argument.  See help(struct) for more\n"
             "on format strings.",
             "module_doc": "Functions to convert between Python values and C structs.\n"
             "Python bytes objects are used to hold the data representing the C struct.\n"
             "The format string (explained below) describes the layout of data\n"
             "in the C struct.\n"
             "\n"
             "The optional first format char indicates byte order, size and alignment:\n"
             "  @: native order, size & alignment (default)\n"
             "  =: native order, std. size & alignment\n"
             "  <: little-endian, std. size & alignment\n"
             "  >: big-endian, std. size & alignment\n"
             "  !: same as >\n"
             "\n"
             "The remaining characters indicate types of args and must match exactly;\n"
             "these can be preceded by a decimal repeat count:\n"
             "  x: pad byte (no data); c: char; b: signed byte; B: unsigned byte;\n"
             "  ?: _Bool; h: short; H: unsigned short; i: int; I: unsigned int;\n"
             "  l: long; L: unsigned long; q: long long; Q: unsigned long long;\n"
             "  f: float; d: double; e: half-float;\n"
             "  F: float complex; D: double complex.\n"
             "Special cases (preceding decimal count indicates length):\n"
             "  s: byte string (array of char); p: Pascal string (with count byte).\n"
             "Special cases (only available in native format):\n"
             "  n: ssize_t; N: size_t;\n"
             "  P: an integer type that is wide enough to hold a pointer.\n"
             "Whitespace between formats is ignored.\n"
             "\n"
             "The variable struct.error is an exception raised on errors.\n",
             "s_getsetlist_format_doc": "struct format string",
             "s_getsetlist_size_doc": "struct size in bytes"
         }
     );
