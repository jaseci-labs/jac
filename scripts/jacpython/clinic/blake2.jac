"""The Argument Clinic signatures of _blake2.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/blake2.jac from them. Taken from
CPython 3.14.6 Modules/blake2module.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_blake2",
         version="3.14.6",
         sources=["Modules/blake2module.c"],
         classes={"blake2b": "Blake2Object *", "blake2s": "Blake2Object *"},
         functions=[
             Function(
                 name="__new__",
                 full_name="_blake2.blake2b.__new__",
                 c_basename="py_blake2b_new",
                 kind="METHOD_NEW",
                 cls="blake2b",
                 docstring="blake2b(data=b'', *, digest_size=_blake2.blake2b.MAX_DIGEST_SIZE,\n"
                 "        key=b'', salt=b'', person=b'', fanout=1, depth=1, leaf_size=0,\n"
                 "        node_offset=0, node_depth=0, inner_size=0, last_node=False,\n"
                 "        usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Return a new BLAKE2b hash object.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="digest_size",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="HACL_HASH_BLAKE2B_OUT_BYTES"
                     ),
                     Parameter(
                         name="key",
                         kind="KEYWORD_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         default_kind="value",
                         py_default=b'',
                         c_default="{.buf = \"\", .obj = NULL, .len = 0}",
                         by_reference=True
                     ),
                     Parameter(
                         name="salt",
                         kind="KEYWORD_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         default_kind="value",
                         py_default=b'',
                         c_default="{.buf = \"\", .obj = NULL, .len = 0}",
                         by_reference=True
                     ),
                     Parameter(
                         name="person",
                         kind="KEYWORD_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         default_kind="value",
                         py_default=b'',
                         c_default="{.buf = \"\", .obj = NULL, .len = 0}",
                         by_reference=True
                     ),
                     Parameter(
                         name="fanout",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=1,
                         c_default="1"
                     ),
                     Parameter(
                         name="depth",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=1,
                         c_default="1"
                     ),
                     Parameter(
                         name="leaf_size",
                         kind="KEYWORD_ONLY",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="O&",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         convert_with="_PyLong_UnsignedLong_Converter"
                     ),
                     Parameter(
                         name="node_offset",
                         kind="KEYWORD_ONLY",
                         converter="unsigned_long_long",
                         type="unsigned long long",
                         format_unit="O&",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         convert_with="_PyLong_UnsignedLongLong_Converter"
                     ),
                     Parameter(
                         name="node_depth",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="inner_size",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="last_node",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="copy",
                 full_name="_blake2.blake2b.copy",
                 c_basename="_blake2_blake2b_copy",
                 cls="blake2b",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy of the hash object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="update",
                 full_name="_blake2.blake2b.update",
                 c_basename="_blake2_blake2b_update",
                 cls="blake2b",
                 docstring="update($self, data, /)\n"
                 "--\n"
                 "\n"
                 "Update this hash object's state with the provided bytes-like object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="data", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="digest",
                 full_name="_blake2.blake2b.digest",
                 c_basename="_blake2_blake2b_digest",
                 cls="blake2b",
                 docstring="digest($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the digest value as a bytes object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="hexdigest",
                 full_name="_blake2.blake2b.hexdigest",
                 c_basename="_blake2_blake2b_hexdigest",
                 cls="blake2b",
                 docstring="hexdigest($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the digest value as a string of hexadecimal digits.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__new__",
                 full_name="_blake2.blake2s.__new__",
                 c_basename="py_blake2s_new",
                 kind="METHOD_NEW",
                 cls="blake2s",
                 docstring="blake2s(data=b'', *, digest_size=_blake2.blake2s.MAX_DIGEST_SIZE,\n"
                 "        key=b'', salt=b'', person=b'', fanout=1, depth=1, leaf_size=0,\n"
                 "        node_offset=0, node_depth=0, inner_size=0, last_node=False,\n"
                 "        usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Return a new BLAKE2s hash object.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="digest_size",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="HACL_HASH_BLAKE2S_OUT_BYTES"
                     ),
                     Parameter(
                         name="key",
                         kind="KEYWORD_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         default_kind="value",
                         py_default=b'',
                         c_default="{.buf = \"\", .obj = NULL, .len = 0}",
                         by_reference=True
                     ),
                     Parameter(
                         name="salt",
                         kind="KEYWORD_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         default_kind="value",
                         py_default=b'',
                         c_default="{.buf = \"\", .obj = NULL, .len = 0}",
                         by_reference=True
                     ),
                     Parameter(
                         name="person",
                         kind="KEYWORD_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         default_kind="value",
                         py_default=b'',
                         c_default="{.buf = \"\", .obj = NULL, .len = 0}",
                         by_reference=True
                     ),
                     Parameter(
                         name="fanout",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=1,
                         c_default="1"
                     ),
                     Parameter(
                         name="depth",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=1,
                         c_default="1"
                     ),
                     Parameter(
                         name="leaf_size",
                         kind="KEYWORD_ONLY",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="O&",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         convert_with="_PyLong_UnsignedLong_Converter"
                     ),
                     Parameter(
                         name="node_offset",
                         kind="KEYWORD_ONLY",
                         converter="unsigned_long_long",
                         type="unsigned long long",
                         format_unit="O&",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         convert_with="_PyLong_UnsignedLongLong_Converter"
                     ),
                     Parameter(
                         name="node_depth",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="inner_size",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="last_node",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             )
         ],
         docs={"blake2mod__doc__": "_blake2b provides BLAKE2b for hashlib\n"}
     );
