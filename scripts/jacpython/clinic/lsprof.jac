"""The Argument Clinic signatures of _lsprof.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/lsprof.jac from them. Taken from
CPython 3.14.6 Modules/_lsprof.c, Modules/rotatingtree.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_lsprof",
         version="3.14.6",
         sources=["Modules/_lsprof.c", "Modules/rotatingtree.c"],
         classes={"Profiler": "ProfilerObject *"},
         functions=[
             Function(
                 name="getstats",
                 full_name="_lsprof.Profiler.getstats",
                 c_basename="_lsprof_Profiler_getstats",
                 cls="Profiler",
                 docstring="getstats($self, /)\n"
                 "--\n"
                 "\n"
                 "list of profiler_entry objects.\n"
                 "\n"
                 "getstats() -> list of profiler_entry objects\n"
                 "\n"
                 "Return all information collected by the profiler.\n"
                 "Each profiler_entry is a tuple-like object with the\n"
                 "following attributes:\n"
                 "\n"
                 "    code          code object\n"
                 "    callcount     how many times this was called\n"
                 "    reccallcount  how many times called recursively\n"
                 "    totaltime     total time in this entry\n"
                 "    inlinetime    inline time in this entry (not in subcalls)\n"
                 "    calls         details of the calls\n"
                 "\n"
                 "The calls attribute is either None or a list of\n"
                 "profiler_subentry objects:\n"
                 "\n"
                 "    code          called code object\n"
                 "    callcount     how many times this is called\n"
                 "    reccallcount  how many times this is called recursively\n"
                 "    totaltime     total time spent in this call\n"
                 "    inlinetime    inline time (not in further subcalls)",
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
                 name="_pystart_callback",
                 full_name="_lsprof.Profiler._pystart_callback",
                 c_basename="_lsprof_Profiler__pystart_callback",
                 cls="Profiler",
                 docstring="_pystart_callback($self, code, instruction_offset, /)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="code", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="instruction_offset",
                         kind="POSITIONAL_ONLY",
                         format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="_pythrow_callback",
                 full_name="_lsprof.Profiler._pythrow_callback",
                 c_basename="_lsprof_Profiler__pythrow_callback",
                 cls="Profiler",
                 docstring="_pythrow_callback($self, code, instruction_offset, exception, /)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="code", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="instruction_offset",
                         kind="POSITIONAL_ONLY",
                         format_unit="O"
                     ),
                     Parameter(
                         name="exception", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="_pyreturn_callback",
                 full_name="_lsprof.Profiler._pyreturn_callback",
                 c_basename="_lsprof_Profiler__pyreturn_callback",
                 cls="Profiler",
                 docstring="_pyreturn_callback($self, code, instruction_offset, retval, /)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="code", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="instruction_offset",
                         kind="POSITIONAL_ONLY",
                         format_unit="O"
                     ),
                     Parameter(name="retval", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="_ccall_callback",
                 full_name="_lsprof.Profiler._ccall_callback",
                 c_basename="_lsprof_Profiler__ccall_callback",
                 cls="Profiler",
                 docstring="_ccall_callback($self, code, instruction_offset, callable, self_arg, /)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="code", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="instruction_offset",
                         kind="POSITIONAL_ONLY",
                         format_unit="O"
                     ),
                     Parameter(
                         name="callable", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(name="self_arg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=4,
                 max_pos=4,
                 pos_only=4
             ),
             Function(
                 name="_creturn_callback",
                 full_name="_lsprof.Profiler._creturn_callback",
                 c_basename="_lsprof_Profiler__creturn_callback",
                 cls="Profiler",
                 docstring="_creturn_callback($self, code, instruction_offset, callable, self_arg,\n"
                 "                  /)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="code", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="instruction_offset",
                         kind="POSITIONAL_ONLY",
                         format_unit="O"
                     ),
                     Parameter(
                         name="callable", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(name="self_arg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=4,
                 max_pos=4,
                 pos_only=4
             ),
             Function(
                 name="enable",
                 full_name="_lsprof.Profiler.enable",
                 c_basename="_lsprof_Profiler_enable",
                 cls="Profiler",
                 docstring="enable($self, /, subcalls=True, builtins=True)\n"
                 "--\n"
                 "\n"
                 "Start collecting profiling information.\n"
                 "\n"
                 "  subcalls\n"
                 "    If True, also records for each function\n"
                 "    statistics separated according to its current caller.\n"
                 "  builtins\n"
                 "    If True, records the time spent in\n"
                 "    built-in functions separately from their caller.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="subcalls",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="builtins",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="disable",
                 full_name="_lsprof.Profiler.disable",
                 c_basename="_lsprof_Profiler_disable",
                 cls="Profiler",
                 docstring="disable($self, /)\n"
                 "--\n"
                 "\n"
                 "Stop collecting profiling information.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="clear",
                 full_name="_lsprof.Profiler.clear",
                 c_basename="_lsprof_Profiler_clear",
                 cls="Profiler",
                 docstring="clear($self, /)\n"
                 "--\n"
                 "\n"
                 "Clear all profiling information collected so far.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__init__",
                 full_name="_lsprof.Profiler.__init__",
                 c_basename="profiler_init",
                 kind="METHOD_INIT",
                 cls="Profiler",
                 docstring="Profiler(timer=None, timeunit=0.0, subcalls=True, builtins=True)\n"
                 "--\n"
                 "\n"
                 "Build a profiler object using the specified timer function.\n"
                 "\n"
                 "The default timer is a fast built-in one based on real time.\n"
                 "For custom timer functions returning integers, 'timeunit' can\n"
                 "be a float specifying a scale (that is, how long each integer unit\n"
                 "is, in seconds).",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="timer",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="timeunit",
                         converter="double",
                         type="double",
                         format_unit="d",
                         default_kind="value",
                         py_default=0.0,
                         c_default="0.0"
                     ),
                     Parameter(
                         name="subcalls",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="builtins",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=4
             )
         ]
     );
