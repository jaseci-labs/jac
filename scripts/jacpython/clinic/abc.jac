"""The Argument Clinic signatures of _abc.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/abc.jac from them. Taken from
CPython 3.14.6 Modules/_abc.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_abc",
         version="3.14.6",
         sources=["Modules/_abc.c"],
         functions=[
             Function(
                 name="_reset_registry",
                 full_name="_abc._reset_registry",
                 c_basename="_abc__reset_registry",
                 docstring="_reset_registry($module, self, /)\n"
                 "--\n"
                 "\n"
                 "Internal ABC helper to reset registry of a given class.\n"
                 "\n"
                 "Should be only used by refleak.py",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="self", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_reset_caches",
                 full_name="_abc._reset_caches",
                 c_basename="_abc__reset_caches",
                 docstring="_reset_caches($module, self, /)\n"
                 "--\n"
                 "\n"
                 "Internal ABC helper to reset both caches of a given class.\n"
                 "\n"
                 "Should be only used by refleak.py",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="self", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_get_dump",
                 full_name="_abc._get_dump",
                 c_basename="_abc__get_dump",
                 docstring="_get_dump($module, self, /)\n"
                 "--\n"
                 "\n"
                 "Internal ABC helper for cache and registry debugging.\n"
                 "\n"
                 "Return shallow copies of registry, of both caches, and\n"
                 "negative cache version. Don't call this function directly,\n"
                 "instead use ABC._dump_registry() for a nice repr.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="self", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_abc_init",
                 full_name="_abc._abc_init",
                 c_basename="_abc__abc_init",
                 docstring="_abc_init($module, self, /)\n"
                 "--\n"
                 "\n"
                 "Internal ABC helper for class set-up. Should be never used outside abc module.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="self", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_abc_register",
                 full_name="_abc._abc_register",
                 c_basename="_abc__abc_register",
                 docstring="_abc_register($module, self, subclass, /)\n"
                 "--\n"
                 "\n"
                 "Internal ABC helper for subclasss registration. Should be never used outside abc module.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="self", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="subclass", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="_abc_instancecheck",
                 full_name="_abc._abc_instancecheck",
                 c_basename="_abc__abc_instancecheck",
                 docstring="_abc_instancecheck($module, self, instance, /)\n"
                 "--\n"
                 "\n"
                 "Internal ABC helper for instance checks. Should be never used outside abc module.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="self", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="instance", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="_abc_subclasscheck",
                 full_name="_abc._abc_subclasscheck",
                 c_basename="_abc__abc_subclasscheck",
                 docstring="_abc_subclasscheck($module, self, subclass, /)\n"
                 "--\n"
                 "\n"
                 "Internal ABC helper for subclasss checks. Should be never used outside abc module.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="self", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="subclass", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="get_cache_token",
                 full_name="_abc.get_cache_token",
                 c_basename="_abc_get_cache_token",
                 docstring="get_cache_token($module, /)\n"
                 "--\n"
                 "\n"
                 "Returns the current ABC cache token.\n"
                 "\n"
                 "The token is an opaque object (supporting equality testing) identifying\n"
                 "the current version of the ABC cache for virtual subclasses.  The token\n"
                 "changes with every call to register() on any ABC.",
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
             )
         ],
         docs={
             "_abc__doc__": "Module contains faster C implementation of abc.ABCMeta",
             "abc_data_doc": "Internal state held by ABC machinery."
         }
     );
