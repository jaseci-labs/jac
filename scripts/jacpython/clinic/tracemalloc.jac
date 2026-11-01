"""The Argument Clinic signatures of _tracemalloc.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/tracemalloc.jac from them. Taken from
CPython 3.14.6 Modules/_tracemalloc.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_tracemalloc",
         version="3.14.6",
         sources=["Modules/_tracemalloc.c"],
         functions=[
             Function(
                 name="is_tracing",
                 full_name="_tracemalloc.is_tracing",
                 c_basename="_tracemalloc_is_tracing",
                 docstring="is_tracing($module, /)\n"
                 "--\n"
                 "\n"
                 "Return True if the tracemalloc module is tracing Python memory allocations.",
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
                 name="clear_traces",
                 full_name="_tracemalloc.clear_traces",
                 c_basename="_tracemalloc_clear_traces",
                 docstring="clear_traces($module, /)\n"
                 "--\n"
                 "\n"
                 "Clear traces of memory blocks allocated by Python.",
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
                 name="_get_traces",
                 full_name="_tracemalloc._get_traces",
                 c_basename="_tracemalloc__get_traces",
                 docstring="_get_traces($module, /)\n"
                 "--\n"
                 "\n"
                 "Get traces of all memory blocks allocated by Python.\n"
                 "\n"
                 "Return a list of (size: int, traceback: tuple) tuples.\n"
                 "traceback is a tuple of (filename: str, lineno: int) tuples.\n"
                 "\n"
                 "Return an empty list if the tracemalloc module is disabled.",
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
                 name="_get_object_traceback",
                 full_name="_tracemalloc._get_object_traceback",
                 c_basename="_tracemalloc__get_object_traceback",
                 docstring="_get_object_traceback($module, obj, /)\n"
                 "--\n"
                 "\n"
                 "Get the traceback where the Python object obj was allocated.\n"
                 "\n"
                 "Return a tuple of (filename: str, lineno: int) tuples.\n"
                 "Return None if the tracemalloc module is disabled or did not\n"
                 "trace the allocation of the object.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
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
                 name="start",
                 full_name="_tracemalloc.start",
                 c_basename="_tracemalloc_start",
                 docstring="start($module, nframe=1, /)\n"
                 "--\n"
                 "\n"
                 "Start tracing Python memory allocations.\n"
                 "\n"
                 "Also set the maximum number of frames stored in the traceback of a\n"
                 "trace to nframe.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="nframe",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=1,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="stop",
                 full_name="_tracemalloc.stop",
                 c_basename="_tracemalloc_stop",
                 docstring="stop($module, /)\n"
                 "--\n"
                 "\n"
                 "Stop tracing Python memory allocations.\n"
                 "\n"
                 "Also clear traces of memory blocks allocated by Python.",
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
                 name="get_traceback_limit",
                 full_name="_tracemalloc.get_traceback_limit",
                 c_basename="_tracemalloc_get_traceback_limit",
                 docstring="get_traceback_limit($module, /)\n"
                 "--\n"
                 "\n"
                 "Get the maximum number of frames stored in the traceback of a trace.\n"
                 "\n"
                 "By default, a trace of an allocated memory block only stores\n"
                 "the most recent frame: the limit is 1.",
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
                 name="get_tracemalloc_memory",
                 full_name="_tracemalloc.get_tracemalloc_memory",
                 c_basename="_tracemalloc_get_tracemalloc_memory",
                 docstring="get_tracemalloc_memory($module, /)\n"
                 "--\n"
                 "\n"
                 "Get the memory usage in bytes of the tracemalloc module.\n"
                 "\n"
                 "This memory is used internally to trace memory allocations.",
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
                 name="get_traced_memory",
                 full_name="_tracemalloc.get_traced_memory",
                 c_basename="_tracemalloc_get_traced_memory",
                 docstring="get_traced_memory($module, /)\n"
                 "--\n"
                 "\n"
                 "Get the current size and peak size of memory blocks traced by tracemalloc.\n"
                 "\n"
                 "Returns a tuple: (current: int, peak: int).",
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
                 name="reset_peak",
                 full_name="_tracemalloc.reset_peak",
                 c_basename="_tracemalloc_reset_peak",
                 docstring="reset_peak($module, /)\n"
                 "--\n"
                 "\n"
                 "Set the peak size of memory blocks traced by tracemalloc to the current size.\n"
                 "\n"
                 "Do nothing if the tracemalloc module is not tracing memory allocations.",
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
         docs={"module_doc": "Debug module to trace memory blocks allocated by Python."}
     );
