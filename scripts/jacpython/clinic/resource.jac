"""The Argument Clinic signatures of resource.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/resource.jac from them. Taken from
CPython 3.14.6 Modules/resource.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="resource",
         version="3.14.6",
         sources=["Modules/resource.c"],
         functions=[
             Function(
                 name="getrusage",
                 full_name="resource.getrusage",
                 c_basename="resource_getrusage",
                 docstring="getrusage($module, who, /)\n" "--",
                 condition="defined(HAVE_GETRUSAGE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="who",
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
                 name="getrlimit",
                 full_name="resource.getrlimit",
                 c_basename="resource_getrlimit",
                 docstring="getrlimit($module, resource, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="resource",
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
                 name="setrlimit",
                 full_name="resource.setrlimit",
                 c_basename="resource_setrlimit",
                 docstring="setrlimit($module, resource, limits, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="resource",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(name="limits", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="prlimit",
                 full_name="resource.prlimit",
                 c_basename="resource_prlimit",
                 docstring="prlimit($module, pid, resource, limits=None, /)\n" "--",
                 condition="defined(HAVE_PRLIMIT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(
                         name="resource",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="limits",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="getpagesize",
                 full_name="resource.getpagesize",
                 c_basename="resource_getpagesize",
                 docstring="getpagesize($module, /)\n" "--",
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
             )
         ],
         docs={
             "struct_rusage__doc__": "struct_rusage: Result from getrusage.\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "    (utime,stime,maxrss,ixrss,idrss,isrss,minflt,majflt,\n"
             "    nswap,inblock,oublock,msgsnd,msgrcv,nsignals,nvcsw,nivcsw)\n"
             "or via the attributes ru_utime, ru_stime, ru_maxrss, and so on."
         }
     );
