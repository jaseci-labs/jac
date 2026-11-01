"""The Argument Clinic signatures of _functools.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/functools.jac from them. Taken from
the C sources it replaces (Modules/_functoolsmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_functools",
         version="3.14.6",
         sources=["Modules/_functoolsmodule.c"],
         classes={"_lru_cache_wrapper": "PyObject *"},
         functions=[
             Function(
                 name="cmp_to_key",
                 full_name="_functools.cmp_to_key",
                 c_basename="_functools_cmp_to_key",
                 docstring="cmp_to_key($module, /, mycmp)\n"
                 "--\n"
                 "\n"
                 "Convert a cmp= function into a key= function.\n"
                 "\n"
                 "  mycmp\n"
                 "    Function that compares two objects.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="mycmp", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="reduce",
                 full_name="_functools.reduce",
                 c_basename="_functools_reduce",
                 docstring="reduce($module, function, iterable, /, initial=<unrepresentable>)\n"
                 "--\n"
                 "\n"
                 "Apply a function of two arguments cumulatively to the items of an iterable, from left to right.\n"
                 "\n"
                 "This effectively reduces the iterable to a single value.  If initial is\n"
                 "present, it is placed before the items of the iterable in the\n"
                 "calculation, and serves as a default when the iterable is empty.\n"
                 "\n"
                 "For example, reduce(lambda x, y: x+y, [1, 2, 3, 4, 5])\n"
                 "calculates ((((1 + 2) + 3) + 4) + 5).",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="function", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="iterable", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="initial",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3,
                 pos_only=2
             ),
             Function(
                 name="cache_info",
                 full_name="_functools._lru_cache_wrapper.cache_info",
                 c_basename="_functools__lru_cache_wrapper_cache_info",
                 cls="_lru_cache_wrapper",
                 docstring="cache_info($self, /)\n"
                 "--\n"
                 "\n"
                 "Report cache statistics",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="cache_clear",
                 full_name="_functools._lru_cache_wrapper.cache_clear",
                 c_basename="_functools__lru_cache_wrapper_cache_clear",
                 cls="_lru_cache_wrapper",
                 docstring="cache_clear($self, /)\n"
                 "--\n"
                 "\n"
                 "Clear the cache and cache statistics",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             )
         ],
         docs={
             "placeholder_doc": "The type of the Placeholder singleton.\n"
             "\n"
             "Used as a placeholder for partial arguments.",
             "partial_doc": "partial(func, /, *args, **keywords)\n"
             "--\n"
             "\n"
             "Create a new function with partial application of the given arguments\n"
             "and keywords.",
             "lru_cache_doc": "Create a cached callable that wraps another function.\n"
             "\n"
             "user_function:      the function being cached\n"
             "\n"
             "maxsize:  0         for no caching\n"
             "          None      for unlimited cache size\n"
             "          n         for a bounded cache\n"
             "\n"
             "typed:    False     cache f(3) and f(3.0) as identical calls\n"
             "          True      cache f(3) and f(3.0) as distinct calls\n"
             "\n"
             "cache_info_type:    namedtuple class with the fields:\n"
             "                        hits misses currsize maxsize\n",
             "_functools_doc": "Tools that operate on functions.",
             "partial_memberlist_func_doc": "function object to use in future partial calls",
             "partial_memberlist_args_doc": "tuple of arguments to future partial calls",
             "partial_memberlist_keywords_doc": "dictionary of keyword arguments to future partial calls",
             "partial_methods___class_getitem___doc": "partial is generic over the wrapped function's return type",
             "keyobject_members_obj_doc": "Value wrapped by a key function."
         }
     );
