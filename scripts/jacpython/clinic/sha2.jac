"""The Argument Clinic signatures of _sha2.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/sha2.jac from them. Taken from
the C sources it replaces (Modules/sha2module.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_sha2",
         version="3.14.6",
         sources=["Modules/sha2module.c"],
         classes={"SHA256Type": "SHA256object *", "SHA512Type": "SHA512object *"},
         functions=[
             Function(
                 name="copy",
                 full_name="SHA256Type.copy",
                 c_basename="SHA256Type_copy",
                 cls="SHA256Type",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy of the hash object.",
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
                 name="digest",
                 full_name="SHA256Type.digest",
                 c_basename="SHA256Type_digest",
                 cls="SHA256Type",
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
                 full_name="SHA256Type.hexdigest",
                 c_basename="SHA256Type_hexdigest",
                 cls="SHA256Type",
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
                 full_name="SHA256Type.update",
                 c_basename="SHA256Type_update",
                 cls="SHA256Type",
                 docstring="update($self, obj, /)\n"
                 "--\n"
                 "\n"
                 "Update this hash object's state with the provided string.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 name="copy",
                 full_name="SHA512Type.copy",
                 c_basename="SHA512Type_copy",
                 cls="SHA512Type",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy of the hash object.",
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
                 name="digest",
                 full_name="SHA512Type.digest",
                 c_basename="SHA512Type_digest",
                 cls="SHA512Type",
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
                 full_name="SHA512Type.hexdigest",
                 c_basename="SHA512Type_hexdigest",
                 cls="SHA512Type",
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
                 full_name="SHA512Type.update",
                 c_basename="SHA512Type_update",
                 cls="SHA512Type",
                 docstring="update($self, obj, /)\n"
                 "--\n"
                 "\n"
                 "Update this hash object's state with the provided string.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 name="sha256",
                 full_name="_sha2.sha256",
                 c_basename="_sha2_sha256",
                 docstring="sha256($module, /, data=b'', *, usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Return a new SHA-256 hash object; optionally initialized with a string.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
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
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="sha224",
                 full_name="_sha2.sha224",
                 c_basename="_sha2_sha224",
                 docstring="sha224($module, /, data=b'', *, usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Return a new SHA-224 hash object; optionally initialized with a string.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
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
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="sha512",
                 full_name="_sha2.sha512",
                 c_basename="_sha2_sha512",
                 docstring="sha512($module, /, data=b'', *, usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Return a new SHA-512 hash object; optionally initialized with a string.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
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
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="sha384",
                 full_name="_sha2.sha384",
                 c_basename="_sha2_sha384",
                 docstring="sha384($module, /, data=b'', *, usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Return a new SHA-384 hash object; optionally initialized with a string.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
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
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             )
         ]
     );
