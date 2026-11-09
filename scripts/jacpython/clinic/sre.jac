"""The Argument Clinic signatures of _sre.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/sre.jac from them. Taken from
CPython 3.14.6 Modules/_sre/sre.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_sre",
         version="3.14.6",
         sources=["Modules/_sre/sre.c"],
         classes={
             "SRE_Pattern": "PatternObject *",
             "SRE_Match": "MatchObject *",
             "SRE_Scanner": "ScannerObject *"
         },
         functions=[
             Function(
                 name="getcodesize",
                 full_name="_sre.getcodesize",
                 c_basename="_sre_getcodesize",
                 docstring="getcodesize($module, /)\n" "--",
                 returns="int",
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
                 name="ascii_iscased",
                 full_name="_sre.ascii_iscased",
                 c_basename="_sre_ascii_iscased",
                 docstring="ascii_iscased($module, character, /)\n" "--",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="character",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="unicode_iscased",
                 full_name="_sre.unicode_iscased",
                 c_basename="_sre_unicode_iscased",
                 docstring="unicode_iscased($module, character, /)\n" "--",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="character",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="ascii_tolower",
                 full_name="_sre.ascii_tolower",
                 c_basename="_sre_ascii_tolower",
                 docstring="ascii_tolower($module, character, /)\n" "--",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="character",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="unicode_tolower",
                 full_name="_sre.unicode_tolower",
                 c_basename="_sre_unicode_tolower",
                 docstring="unicode_tolower($module, character, /)\n" "--",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="character",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="compile",
                 full_name="_sre.compile",
                 c_basename="_sre_compile",
                 docstring="compile($module, /, pattern, flags, code, groups, groupindex,\n"
                 "        indexgroup)\n"
                 "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="pattern", format_unit="O"),
                     Parameter(
                         name="flags", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="code", format_unit="O!", subclass_of="&PyList_Type"
                     ),
                     Parameter(
                         name="groups",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="groupindex", format_unit="O!", subclass_of="&PyDict_Type"
                     ),
                     Parameter(
                         name="indexgroup",
                         format_unit="O!",
                         subclass_of="&PyTuple_Type"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=6,
                 max_pos=6
             ),
             Function(
                 name="template",
                 full_name="_sre.template",
                 c_basename="_sre_template",
                 docstring="template($module, pattern, template, /)\n"
                 "--\n"
                 "\n"
                 "\n"
                 "\n"
                 "  template\n"
                 "    A list containing interleaved literal strings (str or bytes) and group\n"
                 "    indices (int), as returned by re._parser.parse_template():\n"
                 "        [literal1, group1, ..., literalN, groupN]",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="pattern", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="template",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="match",
                 full_name="_sre.SRE_Pattern.match",
                 c_basename="_sre_SRE_Pattern_match",
                 cls="SRE_Pattern",
                 docstring="match($self, /, string, pos=0, endpos=sys.maxsize)\n"
                 "--\n"
                 "\n"
                 "Matches zero or more characters at the beginning of the string.",
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
                     Parameter(name="string", format_unit="O"),
                     Parameter(
                         name="pos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="endpos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=9223372036854775807,
                         c_default="PY_SSIZE_T_MAX"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="fullmatch",
                 full_name="_sre.SRE_Pattern.fullmatch",
                 c_basename="_sre_SRE_Pattern_fullmatch",
                 cls="SRE_Pattern",
                 docstring="fullmatch($self, /, string, pos=0, endpos=sys.maxsize)\n"
                 "--\n"
                 "\n"
                 "Matches against all of the string.",
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
                     Parameter(name="string", format_unit="O"),
                     Parameter(
                         name="pos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="endpos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=9223372036854775807,
                         c_default="PY_SSIZE_T_MAX"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="search",
                 full_name="_sre.SRE_Pattern.search",
                 c_basename="_sre_SRE_Pattern_search",
                 cls="SRE_Pattern",
                 docstring="search($self, /, string, pos=0, endpos=sys.maxsize)\n"
                 "--\n"
                 "\n"
                 "Scan through string looking for a match, and return a corresponding match object instance.\n"
                 "\n"
                 "Return None if no position in the string matches.",
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
                     Parameter(name="string", format_unit="O"),
                     Parameter(
                         name="pos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="endpos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=9223372036854775807,
                         c_default="PY_SSIZE_T_MAX"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="findall",
                 full_name="_sre.SRE_Pattern.findall",
                 c_basename="_sre_SRE_Pattern_findall",
                 cls="SRE_Pattern",
                 docstring="findall($self, /, string, pos=0, endpos=sys.maxsize)\n"
                 "--\n"
                 "\n"
                 "Return a list of all non-overlapping matches of pattern in string.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="string", format_unit="O"),
                     Parameter(
                         name="pos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="endpos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=9223372036854775807,
                         c_default="PY_SSIZE_T_MAX"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="finditer",
                 full_name="_sre.SRE_Pattern.finditer",
                 c_basename="_sre_SRE_Pattern_finditer",
                 cls="SRE_Pattern",
                 docstring="finditer($self, /, string, pos=0, endpos=sys.maxsize)\n"
                 "--\n"
                 "\n"
                 "Return an iterator over all non-overlapping matches for the RE pattern in string.\n"
                 "\n"
                 "For each match, the iterator returns a match object.",
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
                     Parameter(name="string", format_unit="O"),
                     Parameter(
                         name="pos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="endpos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=9223372036854775807,
                         c_default="PY_SSIZE_T_MAX"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="scanner",
                 full_name="_sre.SRE_Pattern.scanner",
                 c_basename="_sre_SRE_Pattern_scanner",
                 cls="SRE_Pattern",
                 docstring="scanner($self, /, string, pos=0, endpos=sys.maxsize)\n"
                 "--",
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
                     Parameter(name="string", format_unit="O"),
                     Parameter(
                         name="pos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="endpos",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=9223372036854775807,
                         c_default="PY_SSIZE_T_MAX"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="split",
                 full_name="_sre.SRE_Pattern.split",
                 c_basename="_sre_SRE_Pattern_split",
                 cls="SRE_Pattern",
                 docstring="split($self, /, string, maxsplit=0)\n"
                 "--\n"
                 "\n"
                 "Split string by the occurrences of pattern.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="string", format_unit="O"),
                     Parameter(
                         name="maxsplit",
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
                 name="sub",
                 full_name="_sre.SRE_Pattern.sub",
                 c_basename="_sre_SRE_Pattern_sub",
                 cls="SRE_Pattern",
                 docstring="sub($self, /, repl, string, count=0)\n"
                 "--\n"
                 "\n"
                 "Return the string obtained by replacing the leftmost non-overlapping occurrences of pattern in string by the replacement repl.",
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
                     Parameter(name="repl", format_unit="O"),
                     Parameter(name="string", format_unit="O"),
                     Parameter(
                         name="count",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3
             ),
             Function(
                 name="subn",
                 full_name="_sre.SRE_Pattern.subn",
                 c_basename="_sre_SRE_Pattern_subn",
                 cls="SRE_Pattern",
                 docstring="subn($self, /, repl, string, count=0)\n"
                 "--\n"
                 "\n"
                 "Return the tuple (new_string, number_of_subs_made) found by replacing the leftmost non-overlapping occurrences of pattern with the replacement repl.",
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
                     Parameter(name="repl", format_unit="O"),
                     Parameter(name="string", format_unit="O"),
                     Parameter(
                         name="count",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3
             ),
             Function(
                 name="__copy__",
                 full_name="_sre.SRE_Pattern.__copy__",
                 c_basename="_sre_SRE_Pattern___copy__",
                 cls="SRE_Pattern",
                 docstring="__copy__($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__deepcopy__",
                 full_name="_sre.SRE_Pattern.__deepcopy__",
                 c_basename="_sre_SRE_Pattern___deepcopy__",
                 cls="SRE_Pattern",
                 docstring="__deepcopy__($self, memo, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="memo", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_fail_after",
                 full_name="_sre.SRE_Pattern._fail_after",
                 c_basename="_sre_SRE_Pattern__fail_after",
                 cls="SRE_Pattern",
                 docstring="_fail_after($self, count, exception, /)\n"
                 "--\n"
                 "\n"
                 "For debugging.",
                 condition="defined(Py_DEBUG)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="count",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="exception", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="expand",
                 full_name="_sre.SRE_Match.expand",
                 c_basename="_sre_SRE_Match_expand",
                 cls="SRE_Match",
                 docstring="expand($self, /, template)\n"
                 "--\n"
                 "\n"
                 "Return the string obtained by doing backslash substitution on the string template, as done by the sub() method.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="template", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="groups",
                 full_name="_sre.SRE_Match.groups",
                 c_basename="_sre_SRE_Match_groups",
                 cls="SRE_Match",
                 docstring="groups($self, /, default=None)\n"
                 "--\n"
                 "\n"
                 "Return a tuple containing all the subgroups of the match, from 1.\n"
                 "\n"
                 "  default\n"
                 "    Is used for groups that did not participate in the match.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="default",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="groupdict",
                 full_name="_sre.SRE_Match.groupdict",
                 c_basename="_sre_SRE_Match_groupdict",
                 cls="SRE_Match",
                 docstring="groupdict($self, /, default=None)\n"
                 "--\n"
                 "\n"
                 "Return a dictionary containing all the named subgroups of the match, keyed by the subgroup name.\n"
                 "\n"
                 "  default\n"
                 "    Is used for groups that did not participate in the match.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="default",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="start",
                 full_name="_sre.SRE_Match.start",
                 c_basename="_sre_SRE_Match_start",
                 cls="SRE_Match",
                 docstring="start($self, group=0, /)\n"
                 "--\n"
                 "\n"
                 "Return index of the start of the substring matched by group.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="group",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=0,
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="end",
                 full_name="_sre.SRE_Match.end",
                 c_basename="_sre_SRE_Match_end",
                 cls="SRE_Match",
                 docstring="end($self, group=0, /)\n"
                 "--\n"
                 "\n"
                 "Return index of the end of the substring matched by group.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="group",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=0,
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="span",
                 full_name="_sre.SRE_Match.span",
                 c_basename="_sre_SRE_Match_span",
                 cls="SRE_Match",
                 docstring="span($self, group=0, /)\n"
                 "--\n"
                 "\n"
                 "For match object m, return the 2-tuple (m.start(group), m.end(group)).",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="group",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=0,
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__copy__",
                 full_name="_sre.SRE_Match.__copy__",
                 c_basename="_sre_SRE_Match___copy__",
                 cls="SRE_Match",
                 docstring="__copy__($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__deepcopy__",
                 full_name="_sre.SRE_Match.__deepcopy__",
                 c_basename="_sre_SRE_Match___deepcopy__",
                 cls="SRE_Match",
                 docstring="__deepcopy__($self, memo, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="memo", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="match",
                 full_name="_sre.SRE_Scanner.match",
                 c_basename="_sre_SRE_Scanner_match",
                 cls="SRE_Scanner",
                 docstring="match($self, /)\n" "--",
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
                 name="search",
                 full_name="_sre.SRE_Scanner.search",
                 c_basename="_sre_SRE_Scanner_search",
                 cls="SRE_Scanner",
                 docstring="search($self, /)\n" "--",
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
             )
         ],
         docs={
             "pattern_doc": "Compiled regular expression object.",
             "match_doc": "The result of re.match() and re.search().\n"
             "Match objects always have a boolean value of True.",
             "match_group_doc": "group([group1, ...]) -> str or tuple.\n"
             "    Return subgroup(s) of the match by indices or names.\n"
             "    For 0 returns the entire match.",
             "pattern_methods___class_getitem___doc": "Patterns are generic over the type of string they handle (str or bytes)",
             "pattern_getset_groupindex_doc": "A dictionary mapping group names to group numbers.",
             "pattern_members_pattern_doc": "The pattern string from which the RE object was compiled.",
             "pattern_members_flags_doc": "The regex matching flags.",
             "pattern_members_groups_doc": "The number of capturing groups in the pattern.",
             "match_methods___class_getitem___doc": "Matches are generic over the type of string which was matched (str or bytes)",
             "match_getset_lastindex_doc": "The integer index of the last matched capturing group.",
             "match_getset_lastgroup_doc": "The name of the last matched capturing group.",
             "match_members_string_doc": "The string passed to match() or search().",
             "match_members_re_doc": "The regular expression object.",
             "match_members_pos_doc": "The index into the string at which the RE engine started looking for a match.",
             "match_members_endpos_doc": "The index into the string beyond which the RE engine will not go."
         }
     );
