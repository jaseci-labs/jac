"""The Argument Clinic signatures of _zoneinfo.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/zoneinfo.jac from them. Taken from
the C sources it replaces (Modules/_zoneinfo.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_zoneinfo",
         version="3.14.6",
         sources=["Modules/_zoneinfo.c"],
         classes={"ZoneInfo": "PyObject *"},
         functions=[
             Function(
                 name="__new__",
                 full_name="zoneinfo.ZoneInfo.__new__",
                 c_basename="zoneinfo_ZoneInfo",
                 kind="METHOD_NEW",
                 cls="ZoneInfo",
                 docstring="ZoneInfo(key)\n"
                 "--\n"
                 "\n"
                 "Create a new ZoneInfo instance.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="key", format_unit="O")
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="from_file",
                 full_name="zoneinfo.ZoneInfo.from_file",
                 c_basename="zoneinfo_ZoneInfo_from_file",
                 kind="CLASS_METHOD",
                 cls="ZoneInfo",
                 docstring="from_file($type, file_obj, /, key=None)\n"
                 "--\n"
                 "\n"
                 "Create a ZoneInfo file from a file object.",
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
                         name="file_obj", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="key",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS|METH_CLASS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2,
                 pos_only=1
             ),
             Function(
                 name="no_cache",
                 full_name="zoneinfo.ZoneInfo.no_cache",
                 c_basename="zoneinfo_ZoneInfo_no_cache",
                 kind="CLASS_METHOD",
                 cls="ZoneInfo",
                 docstring="no_cache($type, /, key)\n"
                 "--\n"
                 "\n"
                 "Get a new instance of ZoneInfo, bypassing the cache.",
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
                     Parameter(name="key", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS|METH_CLASS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="clear_cache",
                 full_name="zoneinfo.ZoneInfo.clear_cache",
                 c_basename="zoneinfo_ZoneInfo_clear_cache",
                 kind="CLASS_METHOD",
                 cls="ZoneInfo",
                 docstring="clear_cache($type, /, *, only_keys=None)\n"
                 "--\n"
                 "\n"
                 "Clear the ZoneInfo cache.",
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
                         name="only_keys",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS|METH_CLASS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="utcoffset",
                 full_name="zoneinfo.ZoneInfo.utcoffset",
                 c_basename="zoneinfo_ZoneInfo_utcoffset",
                 cls="ZoneInfo",
                 docstring="utcoffset($self, dt, /)\n"
                 "--\n"
                 "\n"
                 "Retrieve a timedelta representing the UTC offset in a zone at the given datetime.",
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
                     Parameter(name="dt", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="dst",
                 full_name="zoneinfo.ZoneInfo.dst",
                 c_basename="zoneinfo_ZoneInfo_dst",
                 cls="ZoneInfo",
                 docstring="dst($self, dt, /)\n"
                 "--\n"
                 "\n"
                 "Retrieve a timedelta representing the amount of DST applied in a zone at the given datetime.",
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
                     Parameter(name="dt", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="tzname",
                 full_name="zoneinfo.ZoneInfo.tzname",
                 c_basename="zoneinfo_ZoneInfo_tzname",
                 cls="ZoneInfo",
                 docstring="tzname($self, dt, /)\n"
                 "--\n"
                 "\n"
                 "Retrieve a string containing the abbreviation for the time zone that applies in a zone at a given datetime.",
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
                     Parameter(name="dt", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_unpickle",
                 full_name="zoneinfo.ZoneInfo._unpickle",
                 c_basename="zoneinfo_ZoneInfo__unpickle",
                 kind="CLASS_METHOD",
                 cls="ZoneInfo",
                 docstring="_unpickle($type, key, from_cache, /)\n"
                 "--\n"
                 "\n"
                 "Private method used in unpickling.",
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
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="from_cache",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_char",
                         type="unsigned char",
                         format_unit="B"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS|METH_CLASS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             )
         ],
         docs={
             "zoneinfo_methods_fromutc_doc": "Given a datetime with local time in UTC, retrieve an adjusted datetime in local time.",
             "zoneinfo_methods___reduce___doc": "Function for serialization with the pickle protocol.",
             "zoneinfo_methods___init_subclass___doc": "Function to initialize subclasses."
         }
     );
