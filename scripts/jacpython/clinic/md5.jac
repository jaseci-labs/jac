"""The Argument Clinic signatures of _md5.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/md5.jac from them. Taken from
CPython 3.14.6 Modules/md5module.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_md5",
         version="3.14.6",
         sources=["Modules/md5module.c"],
         classes={"MD5Type": "MD5object *"},
         functions=[
             Function(
                 name="copy",
                 full_name="MD5Type.copy",
                 c_basename="MD5Type_copy",
                 cls="MD5Type",
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
                 full_name="MD5Type.digest",
                 c_basename="MD5Type_digest",
                 cls="MD5Type",
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
                 full_name="MD5Type.hexdigest",
                 c_basename="MD5Type_hexdigest",
                 cls="MD5Type",
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
                 full_name="MD5Type.update",
                 c_basename="MD5Type_update",
                 cls="MD5Type",
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
                 name="md5",
                 full_name="_md5.md5",
                 c_basename="_md5_md5",
                 docstring="md5($module, /, data=b'', *, usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Return a new MD5 hash object; optionally initialized with a string.",
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
