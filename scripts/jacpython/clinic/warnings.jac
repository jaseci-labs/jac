"""The Argument Clinic signatures of _warnings.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/warnings.jac from them. Taken from
CPython 3.14.6 Python/_warnings.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_warnings",
         version="3.14.6",
         sources=["Python/_warnings.c"],
         functions=[
             Function(
                 name="_acquire_lock",
                 full_name="_acquire_lock",
                 c_basename="warnings_acquire_lock",
                 docstring="_acquire_lock($module, /)\n" "--",
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
                 name="_release_lock",
                 full_name="_release_lock",
                 c_basename="warnings_release_lock",
                 docstring="_release_lock($module, /)\n" "--",
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
                 name="warn",
                 full_name="warn",
                 c_basename="warnings_warn",
                 docstring="warn($module, /, message, category=None, stacklevel=1, source=None, *,\n"
                 "     skip_file_prefixes=<unrepresentable>)\n"
                 "--\n"
                 "\n"
                 "Issue a warning, or maybe ignore it or raise an exception.\n"
                 "\n"
                 "  message\n"
                 "    Text of the warning message.\n"
                 "  category\n"
                 "    The Warning category subclass. Defaults to UserWarning.\n"
                 "  stacklevel\n"
                 "    How far up the call stack to make this warning appear. A value of 2 for\n"
                 "    example attributes the warning to the caller of the code calling warn().\n"
                 "  source\n"
                 "    If supplied, the destroyed object which emitted a ResourceWarning\n"
                 "  skip_file_prefixes\n"
                 "    An optional tuple of module filename prefixes indicating frames to skip\n"
                 "    during stacklevel computations for stack frame attribution.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="message", format_unit="O"),
                     Parameter(
                         name="category",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="stacklevel",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=1,
                         c_default="1"
                     ),
                     Parameter(
                         name="source",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="skip_file_prefixes",
                         kind="KEYWORD_ONLY",
                         type="PyTupleObject *",
                         format_unit="O!",
                         default_kind="NULL",
                         c_default="NULL",
                         subclass_of="&PyTuple_Type"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=4
             ),
             Function(
                 name="warn_explicit",
                 full_name="warn_explicit",
                 c_basename="warnings_warn_explicit",
                 docstring="warn_explicit($module, /, message, category, filename, lineno,\n"
                 "              module=<unrepresentable>, registry=None,\n"
                 "              module_globals=None, source=None)\n"
                 "--\n"
                 "\n"
                 "Issue a warning, or maybe ignore it or raise an exception.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="message", format_unit="O"),
                     Parameter(name="category", format_unit="O"),
                     Parameter(name="filename", converter="unicode", format_unit="U"),
                     Parameter(
                         name="lineno", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="module",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="registry",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="module_globals",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="source",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=4,
                 max_pos=8
             ),
             Function(
                 name="_filters_mutated_lock_held",
                 full_name="_filters_mutated_lock_held",
                 c_basename="warnings_filters_mutated_lock_held",
                 docstring="_filters_mutated_lock_held($module, /)\n" "--",
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
             "warnings__doc__": " provides basic warning filtering support.\n"
             "It is a helper module to speed up interpreter start-up."
         }
     );
