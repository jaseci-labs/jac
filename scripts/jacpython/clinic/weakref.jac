"""The Argument Clinic signatures of _weakref.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/weakref.jac from them. Taken from
CPython 3.14.6 Modules/_weakref.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_weakref",
         version="3.14.6",
         sources=["Modules/_weakref.c"],
         functions=[
             Function(
                 name="getweakrefcount",
                 full_name="_weakref.getweakrefcount",
                 c_basename="_weakref_getweakrefcount",
                 docstring="getweakrefcount($module, object, /)\n"
                 "--\n"
                 "\n"
                 "Return the number of weak references to 'object'.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="object", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_remove_dead_weakref",
                 full_name="_weakref._remove_dead_weakref",
                 c_basename="_weakref__remove_dead_weakref",
                 docstring="_remove_dead_weakref($module, dct, key, /)\n"
                 "--\n"
                 "\n"
                 "Atomically remove key from dict if it points to a dead weakref.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="dct",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyDict_Type"
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="getweakrefs",
                 full_name="_weakref.getweakrefs",
                 c_basename="_weakref_getweakrefs",
                 docstring="getweakrefs($module, object, /)\n"
                 "--\n"
                 "\n"
                 "Return a list of all weak reference objects pointing to 'object'.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="object", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="proxy",
                 full_name="_weakref.proxy",
                 c_basename="_weakref_proxy",
                 docstring="proxy($module, object, callback=None, /)\n"
                 "--\n"
                 "\n"
                 "Create a proxy object that weakly references 'object'.\n"
                 "\n"
                 "'callback', if given, is called with a reference to the\n"
                 "proxy when 'object' is about to be finalized.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="object", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="callback",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             )
         ]
     );
