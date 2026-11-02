"""The Argument Clinic signatures of _sha3.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/sha3.jac from them. Taken from
CPython 3.14.6 Modules/sha3module.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_sha3",
         version="3.14.6",
         sources=["Modules/sha3module.c"],
         classes={"sha3_224": "SHA3object *", "shake_128": "SHA3object *"},
         functions=[
             Function(
                 name="__new__",
                 full_name="_sha3.sha3_224.__new__",
                 c_basename="py_sha3_new",
                 kind="METHOD_NEW",
                 cls="sha3_224",
                 docstring="sha3_224(data=b'', *, usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Return a new SHA3 hash object.",
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
                 full_name="_sha3.sha3_224.copy",
                 c_basename="_sha3_sha3_224_copy",
                 cls="sha3_224",
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
                 name="digest",
                 full_name="_sha3.sha3_224.digest",
                 c_basename="_sha3_sha3_224_digest",
                 cls="sha3_224",
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
                 full_name="_sha3.sha3_224.hexdigest",
                 c_basename="_sha3_sha3_224_hexdigest",
                 cls="sha3_224",
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
                 name="update",
                 full_name="_sha3.sha3_224.update",
                 c_basename="_sha3_sha3_224_update",
                 cls="sha3_224",
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
                 full_name="_sha3.shake_128.digest",
                 c_basename="_sha3_shake_128_digest",
                 cls="shake_128",
                 docstring="digest($self, /, length)\n"
                 "--\n"
                 "\n"
                 "Return the digest value as a bytes object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="length",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedLong_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="hexdigest",
                 full_name="_sha3.shake_128.hexdigest",
                 c_basename="_sha3_shake_128_hexdigest",
                 cls="shake_128",
                 docstring="hexdigest($self, /, length)\n"
                 "--\n"
                 "\n"
                 "Return the digest value as a string of hexadecimal digits.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="length",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedLong_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             )
         ],
         docs={
             "sha3_224__doc__": "sha3_224([data], *, usedforsecurity=True) -> SHA3 object\n"
             "\n"
             "Return a new SHA3 hash object with a hashbit length of 28 bytes.",
             "sha3_256__doc__": "sha3_256([data], *, usedforsecurity=True) -> SHA3 object\n"
             "\n"
             "Return a new SHA3 hash object with a hashbit length of 32 bytes.",
             "sha3_384__doc__": "sha3_384([data], *, usedforsecurity=True) -> SHA3 object\n"
             "\n"
             "Return a new SHA3 hash object with a hashbit length of 48 bytes.",
             "sha3_512__doc__": "sha3_512([data], *, usedforsecurity=True) -> SHA3 object\n"
             "\n"
             "Return a new SHA3 hash object with a hashbit length of 64 bytes.",
             "shake_128__doc__": "shake_128([data], *, usedforsecurity=True) -> SHAKE object\n"
             "\n"
             "Return a new SHAKE hash object.",
             "shake_256__doc__": "shake_256([data], *, usedforsecurity=True) -> SHAKE object\n"
             "\n"
             "Return a new SHAKE hash object."
         }
     );
