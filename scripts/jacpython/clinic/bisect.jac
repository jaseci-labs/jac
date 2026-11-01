"""The Argument Clinic signatures of _bisect.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/bisect.jac from them. Taken from
the C sources it replaces (Modules/_bisectmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_bisect",
         version="3.14.6",
         sources=["Modules/_bisectmodule.c"],
         functions=[
             Function(
                 name="bisect_right",
                 full_name="_bisect.bisect_right",
                 c_basename="_bisect_bisect_right",
                 docstring="bisect_right($module, /, a, x, lo=0, hi=None, *, key=None)\n"
                 "--\n"
                 "\n"
                 "Return the index where to insert item x in list a, assuming a is sorted.\n"
                 "\n"
                 "The return value i is such that all e in a[:i] have e <= x, and all e in\n"
                 "a[i:] have e > x.  So if x already appears in the list, a.insert(i, x)\n"
                 "will insert just after the rightmost x already there.\n"
                 "\n"
                 "Optional args lo (default 0) and hi (default len(a)) bound the\n"
                 "slice of a to be searched.\n"
                 "\n"
                 "A custom key function can be supplied to customize the sort order.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", format_unit="O"),
                     Parameter(name="x", format_unit="O"),
                     Parameter(
                         name="lo",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="hi",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     ),
                     Parameter(
                         name="key",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=4
             ),
             Function(
                 name="insort_right",
                 full_name="_bisect.insort_right",
                 c_basename="_bisect_insort_right",
                 docstring="insort_right($module, /, a, x, lo=0, hi=None, *, key=None)\n"
                 "--\n"
                 "\n"
                 "Insert item x in list a, and keep it sorted assuming a is sorted.\n"
                 "\n"
                 "If x is already in a, insert it to the right of the rightmost x.\n"
                 "\n"
                 "Optional args lo (default 0) and hi (default len(a)) bound the\n"
                 "slice of a to be searched.\n"
                 "\n"
                 "A custom key function can be supplied to customize the sort order.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", format_unit="O"),
                     Parameter(name="x", format_unit="O"),
                     Parameter(
                         name="lo",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="hi",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     ),
                     Parameter(
                         name="key",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=4
             ),
             Function(
                 name="bisect_left",
                 full_name="_bisect.bisect_left",
                 c_basename="_bisect_bisect_left",
                 docstring="bisect_left($module, /, a, x, lo=0, hi=None, *, key=None)\n"
                 "--\n"
                 "\n"
                 "Return the index where to insert item x in list a, assuming a is sorted.\n"
                 "\n"
                 "The return value i is such that all e in a[:i] have e < x, and all e in\n"
                 "a[i:] have e >= x.  So if x already appears in the list, a.insert(i, x)\n"
                 "will insert just before the leftmost x already there.\n"
                 "\n"
                 "Optional args lo (default 0) and hi (default len(a)) bound the\n"
                 "slice of a to be searched.\n"
                 "\n"
                 "A custom key function can be supplied to customize the sort order.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", format_unit="O"),
                     Parameter(name="x", format_unit="O"),
                     Parameter(
                         name="lo",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="hi",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     ),
                     Parameter(
                         name="key",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=4
             ),
             Function(
                 name="insort_left",
                 full_name="_bisect.insort_left",
                 c_basename="_bisect_insort_left",
                 docstring="insort_left($module, /, a, x, lo=0, hi=None, *, key=None)\n"
                 "--\n"
                 "\n"
                 "Insert item x in list a, and keep it sorted assuming a is sorted.\n"
                 "\n"
                 "If x is already in a, insert it to the left of the leftmost x.\n"
                 "\n"
                 "Optional args lo (default 0) and hi (default len(a)) bound the\n"
                 "slice of a to be searched.\n"
                 "\n"
                 "A custom key function can be supplied to customize the sort order.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", format_unit="O"),
                     Parameter(name="x", format_unit="O"),
                     Parameter(
                         name="lo",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="hi",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     ),
                     Parameter(
                         name="key",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=4
             )
         ],
         docs={
             "module_doc": "Bisection algorithms.\n"
             "\n"
             "This module provides support for maintaining a list in sorted order without\n"
             "having to sort the list after each insertion. For long lists of items with\n"
             "expensive comparison operations, this can be an improvement over the more\n"
             "common approach.\n"
         }
     );
