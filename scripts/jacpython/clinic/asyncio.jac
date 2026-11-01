"""The Argument Clinic signatures of _asyncio.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/asyncio.jac from them. Taken from
the C sources it replaces (Modules/_asynciomodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_asyncio",
         version="3.14.6",
         sources=["Modules/_asynciomodule.c"],
         classes={"Future": "FutureObj *", "Task": "TaskObj *"},
         functions=[
             Function(
                 name="_get_running_loop",
                 full_name="_asyncio._get_running_loop",
                 c_basename="_asyncio__get_running_loop",
                 docstring="_get_running_loop($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the running event loop or None.\n"
                 "\n"
                 "This is a low-level function intended to be used by event loops.\n"
                 "This function is thread-specific.",
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
                 name="_set_running_loop",
                 full_name="_asyncio._set_running_loop",
                 c_basename="_asyncio__set_running_loop",
                 docstring="_set_running_loop($module, loop, /)\n"
                 "--\n"
                 "\n"
                 "Set the running event loop.\n"
                 "\n"
                 "This is a low-level function intended to be used by event loops.\n"
                 "This function is thread-specific.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="loop", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="get_event_loop",
                 full_name="_asyncio.get_event_loop",
                 c_basename="_asyncio_get_event_loop",
                 docstring="get_event_loop($module, /)\n"
                 "--\n"
                 "\n"
                 "Return an asyncio event loop.\n"
                 "\n"
                 "When called from a coroutine or a callback (e.g. scheduled with\n"
                 "call_soon or similar API), this function will always return the\n"
                 "running event loop.\n"
                 "\n"
                 "If there is no running event loop set, the function will return\n"
                 "the result of `get_event_loop_policy().get_event_loop()` call.",
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
                 name="get_running_loop",
                 full_name="_asyncio.get_running_loop",
                 c_basename="_asyncio_get_running_loop",
                 docstring="get_running_loop($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the running event loop.  Raise a RuntimeError if there is none.\n"
                 "\n"
                 "This function is thread-specific.",
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
                 name="_register_task",
                 full_name="_asyncio._register_task",
                 c_basename="_asyncio__register_task",
                 docstring="_register_task($module, /, task)\n"
                 "--\n"
                 "\n"
                 "Register a new task in asyncio as executed by loop.\n"
                 "\n"
                 "Returns None.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="task", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_register_eager_task",
                 full_name="_asyncio._register_eager_task",
                 c_basename="_asyncio__register_eager_task",
                 docstring="_register_eager_task($module, /, task)\n"
                 "--\n"
                 "\n"
                 "Register a new task in asyncio as executed by loop.\n"
                 "\n"
                 "Returns None.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="task", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_unregister_task",
                 full_name="_asyncio._unregister_task",
                 c_basename="_asyncio__unregister_task",
                 docstring="_unregister_task($module, /, task)\n"
                 "--\n"
                 "\n"
                 "Unregister a task.\n"
                 "\n"
                 "Returns None.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="task", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_unregister_eager_task",
                 full_name="_asyncio._unregister_eager_task",
                 c_basename="_asyncio__unregister_eager_task",
                 docstring="_unregister_eager_task($module, /, task)\n"
                 "--\n"
                 "\n"
                 "Unregister a task.\n"
                 "\n"
                 "Returns None.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="task", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_enter_task",
                 full_name="_asyncio._enter_task",
                 c_basename="_asyncio__enter_task",
                 docstring="_enter_task($module, /, loop, task)\n"
                 "--\n"
                 "\n"
                 "Enter into task execution or resume suspended task.\n"
                 "\n"
                 "Task belongs to loop.\n"
                 "\n"
                 "Returns None.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="loop", format_unit="O"),
                     Parameter(name="task", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="_leave_task",
                 full_name="_asyncio._leave_task",
                 c_basename="_asyncio__leave_task",
                 docstring="_leave_task($module, /, loop, task)\n"
                 "--\n"
                 "\n"
                 "Leave task execution or suspend a task.\n"
                 "\n"
                 "Task belongs to loop.\n"
                 "\n"
                 "Returns None.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="loop", format_unit="O"),
                     Parameter(name="task", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="_swap_current_task",
                 full_name="_asyncio._swap_current_task",
                 c_basename="_asyncio__swap_current_task",
                 docstring="_swap_current_task($module, /, loop, task)\n"
                 "--\n"
                 "\n"
                 "Temporarily swap in the supplied task and return the original one (or None).\n"
                 "\n"
                 "This is intended for use during eager coroutine execution.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="loop", format_unit="O"),
                     Parameter(name="task", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="current_task",
                 full_name="_asyncio.current_task",
                 c_basename="_asyncio_current_task",
                 docstring="current_task($module, /, loop=None)\n"
                 "--\n"
                 "\n"
                 "Return a currently executed task.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="loop",
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
                 name="all_tasks",
                 full_name="_asyncio.all_tasks",
                 c_basename="_asyncio_all_tasks",
                 docstring="all_tasks($module, /, loop=None)\n"
                 "--\n"
                 "\n"
                 "Return a set of all tasks for the loop.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="loop",
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
                 name="future_add_to_awaited_by",
                 full_name="_asyncio.future_add_to_awaited_by",
                 c_basename="_asyncio_future_add_to_awaited_by",
                 docstring="future_add_to_awaited_by($module, fut, waiter, /)\n"
                 "--\n"
                 "\n"
                 "Record that `fut` is awaited on by `waiter`.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="fut", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="waiter", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="future_discard_from_awaited_by",
                 full_name="_asyncio.future_discard_from_awaited_by",
                 c_basename="_asyncio_future_discard_from_awaited_by",
                 docstring="future_discard_from_awaited_by($module, fut, waiter, /)\n"
                 "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="fut", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="waiter", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="__init__",
                 full_name="_asyncio.Future.__init__",
                 c_basename="_asyncio_Future___init__",
                 kind="METHOD_INIT",
                 cls="Future",
                 docstring="Future(*, loop=None)\n"
                 "--\n"
                 "\n"
                 "This class is *almost* compatible with concurrent.futures.Future.\n"
                 "\n"
                 "    Differences:\n"
                 "\n"
                 "    - result() and exception() do not take a timeout argument and\n"
                 "      raise an exception when the future isn't done yet.\n"
                 "\n"
                 "    - Callbacks registered with add_done_callback() are always called\n"
                 "      via the event loop's call_soon_threadsafe().\n"
                 "\n"
                 "    - This class is not compatible with the wait() and as_completed()\n"
                 "      methods in the concurrent.futures package.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="loop",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="result",
                 full_name="_asyncio.Future.result",
                 c_basename="_asyncio_Future_result",
                 cls="Future",
                 docstring="result($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the result this future represents.\n"
                 "\n"
                 "If the future has been cancelled, raises CancelledError.  If the\n"
                 "future's result isn't yet available, raises InvalidStateError.  If\n"
                 "the future is done and has an exception set, this exception is\n"
                 "raised.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="exception",
                 full_name="_asyncio.Future.exception",
                 c_basename="_asyncio_Future_exception",
                 cls="Future",
                 docstring="exception($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the exception that was set on this future.\n"
                 "\n"
                 "The exception (or None if no exception was set) is returned only if\n"
                 "the future is done.  If the future has been cancelled, raises\n"
                 "CancelledError.  If the future isn't done yet, raises\n"
                 "InvalidStateError.",
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
                 name="set_result",
                 full_name="_asyncio.Future.set_result",
                 c_basename="_asyncio_Future_set_result",
                 cls="Future",
                 docstring="set_result($self, result, /)\n"
                 "--\n"
                 "\n"
                 "Mark the future done and set its result.\n"
                 "\n"
                 "If the future is already done when this method is called, raises\n"
                 "InvalidStateError.",
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
                     Parameter(name="result", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="set_exception",
                 full_name="_asyncio.Future.set_exception",
                 c_basename="_asyncio_Future_set_exception",
                 cls="Future",
                 docstring="set_exception($self, exception, /)\n"
                 "--\n"
                 "\n"
                 "Mark the future done and set an exception.\n"
                 "\n"
                 "If the future is already done when this method is called, raises\n"
                 "InvalidStateError.",
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
                     Parameter(
                         name="exception", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="add_done_callback",
                 full_name="_asyncio.Future.add_done_callback",
                 c_basename="_asyncio_Future_add_done_callback",
                 cls="Future",
                 docstring="add_done_callback($self, fn, /, *, context=<unrepresentable>)\n"
                 "--\n"
                 "\n"
                 "Add a callback to be run when the future becomes done.\n"
                 "\n"
                 "The callback is called with a single argument - the future object.\n"
                 "If the future is already done when this is called, the callback is\n"
                 "scheduled with call_soon.",
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
                     Parameter(name="fn", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="context",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="remove_done_callback",
                 full_name="_asyncio.Future.remove_done_callback",
                 c_basename="_asyncio_Future_remove_done_callback",
                 cls="Future",
                 docstring="remove_done_callback($self, fn, /)\n"
                 "--\n"
                 "\n"
                 "Remove all instances of a callback from the \"call when done\" list.\n"
                 "\n"
                 "Returns the number of callbacks removed.",
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
                     Parameter(name="fn", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="cancel",
                 full_name="_asyncio.Future.cancel",
                 c_basename="_asyncio_Future_cancel",
                 cls="Future",
                 docstring="cancel($self, /, msg=None)\n"
                 "--\n"
                 "\n"
                 "Cancel the future and schedule callbacks.\n"
                 "\n"
                 "If the future is already done or cancelled, return False.\n"
                 "Otherwise, change the future's state to cancelled, schedule the\n"
                 "callbacks and return True.",
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
                     Parameter(
                         name="msg",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="cancelled",
                 full_name="_asyncio.Future.cancelled",
                 c_basename="_asyncio_Future_cancelled",
                 cls="Future",
                 docstring="cancelled($self, /)\n"
                 "--\n"
                 "\n"
                 "Return True if the future was cancelled.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="done",
                 full_name="_asyncio.Future.done",
                 c_basename="_asyncio_Future_done",
                 cls="Future",
                 docstring="done($self, /)\n"
                 "--\n"
                 "\n"
                 "Return True if the future is done.\n"
                 "\n"
                 "Done means either that a result / exception are available, or that\n"
                 "the future was cancelled.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="get_loop",
                 full_name="_asyncio.Future.get_loop",
                 c_basename="_asyncio_Future_get_loop",
                 cls="Future",
                 docstring="get_loop($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the event loop the Future is bound to.",
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
                 name="_asyncio_awaited_by",
                 full_name="_asyncio.Future._asyncio_awaited_by",
                 c_basename="_asyncio_Future__asyncio_awaited_by",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_asyncio_future_blocking",
                 full_name="_asyncio.Future._asyncio_future_blocking",
                 c_basename="_asyncio_Future__asyncio_future_blocking",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_asyncio_future_blocking",
                 full_name="_asyncio.Future._asyncio_future_blocking",
                 c_basename="_asyncio_Future__asyncio_future_blocking",
                 kind="SETTER",
                 cls="Future",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_log_traceback",
                 full_name="_asyncio.Future._log_traceback",
                 c_basename="_asyncio_Future__log_traceback",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_log_traceback",
                 full_name="_asyncio.Future._log_traceback",
                 c_basename="_asyncio_Future__log_traceback",
                 kind="SETTER",
                 cls="Future",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_loop",
                 full_name="_asyncio.Future._loop",
                 c_basename="_asyncio_Future__loop",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_callbacks",
                 full_name="_asyncio.Future._callbacks",
                 c_basename="_asyncio_Future__callbacks",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_result",
                 full_name="_asyncio.Future._result",
                 c_basename="_asyncio_Future__result",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_exception",
                 full_name="_asyncio.Future._exception",
                 c_basename="_asyncio_Future__exception",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_source_traceback",
                 full_name="_asyncio.Future._source_traceback",
                 c_basename="_asyncio_Future__source_traceback",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_cancel_message",
                 full_name="_asyncio.Future._cancel_message",
                 c_basename="_asyncio_Future__cancel_message",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_cancel_message",
                 full_name="_asyncio.Future._cancel_message",
                 c_basename="_asyncio_Future__cancel_message",
                 kind="SETTER",
                 cls="Future",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_state",
                 full_name="_asyncio.Future._state",
                 c_basename="_asyncio_Future__state",
                 kind="GETTER",
                 cls="Future",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_make_cancelled_error",
                 full_name="_asyncio.Future._make_cancelled_error",
                 c_basename="_asyncio_Future__make_cancelled_error",
                 cls="Future",
                 docstring="_make_cancelled_error($self, /)\n"
                 "--\n"
                 "\n"
                 "Create the CancelledError to raise if the Future is cancelled.\n"
                 "\n"
                 "This should only be called once when handling a cancellation since\n"
                 "it erases the context exception value.",
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
                 full_name="_asyncio.Task.__init__",
                 c_basename="_asyncio_Task___init__",
                 kind="METHOD_INIT",
                 cls="Task",
                 docstring="Task(coro, *, loop=None, name=None, context=None, eager_start=False)\n"
                 "--\n"
                 "\n"
                 "A coroutine wrapped in a Future.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="coro", format_unit="O"),
                     Parameter(
                         name="loop",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="name",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="context",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="eager_start",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_log_destroy_pending",
                 full_name="_asyncio.Task._log_destroy_pending",
                 c_basename="_asyncio_Task__log_destroy_pending",
                 kind="GETTER",
                 cls="Task",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_log_destroy_pending",
                 full_name="_asyncio.Task._log_destroy_pending",
                 c_basename="_asyncio_Task__log_destroy_pending",
                 kind="SETTER",
                 cls="Task",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_must_cancel",
                 full_name="_asyncio.Task._must_cancel",
                 c_basename="_asyncio_Task__must_cancel",
                 kind="GETTER",
                 cls="Task",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_coro",
                 full_name="_asyncio.Task._coro",
                 c_basename="_asyncio_Task__coro",
                 kind="GETTER",
                 cls="Task",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_fut_waiter",
                 full_name="_asyncio.Task._fut_waiter",
                 c_basename="_asyncio_Task__fut_waiter",
                 kind="GETTER",
                 cls="Task",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_make_cancelled_error",
                 full_name="_asyncio.Task._make_cancelled_error",
                 c_basename="_asyncio_Task__make_cancelled_error",
                 cls="Task",
                 docstring="_make_cancelled_error($self, /)\n"
                 "--\n"
                 "\n"
                 "Create the CancelledError to raise if the Task is cancelled.\n"
                 "\n"
                 "This should only be called once when handling a cancellation since\n"
                 "it erases the context exception value.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="cancel",
                 full_name="_asyncio.Task.cancel",
                 c_basename="_asyncio_Task_cancel",
                 cls="Task",
                 docstring="cancel($self, /, msg=None)\n"
                 "--\n"
                 "\n"
                 "Request that this task cancel itself.\n"
                 "\n"
                 "This arranges for a CancelledError to be thrown into the\n"
                 "wrapped coroutine on the next cycle through the event loop.\n"
                 "The coroutine then has a chance to clean up or even deny\n"
                 "the request using try/except/finally.\n"
                 "\n"
                 "Unlike Future.cancel, this does not guarantee that the\n"
                 "task will be cancelled: the exception might be caught and\n"
                 "acted upon, delaying cancellation of the task or preventing\n"
                 "cancellation completely.  The task may also return a value or\n"
                 "raise a different exception.\n"
                 "\n"
                 "Immediately after this method is called, Task.cancelled() will\n"
                 "not return True (unless the task was already cancelled).  A\n"
                 "task will be marked as cancelled when the wrapped coroutine\n"
                 "terminates with a CancelledError exception (even if cancel()\n"
                 "was not called).\n"
                 "\n"
                 "This also increases the task's count of cancellation requests.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="msg",
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
                 name="cancelling",
                 full_name="_asyncio.Task.cancelling",
                 c_basename="_asyncio_Task_cancelling",
                 cls="Task",
                 docstring="cancelling($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the count of the task's cancellation requests.\n"
                 "\n"
                 "This count is incremented when .cancel() is called\n"
                 "and may be decremented using .uncancel().",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="uncancel",
                 full_name="_asyncio.Task.uncancel",
                 c_basename="_asyncio_Task_uncancel",
                 cls="Task",
                 docstring="uncancel($self, /)\n"
                 "--\n"
                 "\n"
                 "Decrement the task's count of cancellation requests.\n"
                 "\n"
                 "This should be used by tasks that catch CancelledError\n"
                 "and wish to continue indefinitely until they are cancelled again.\n"
                 "\n"
                 "Returns the remaining number of cancellation requests.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="get_stack",
                 full_name="_asyncio.Task.get_stack",
                 c_basename="_asyncio_Task_get_stack",
                 cls="Task",
                 docstring="get_stack($self, /, *, limit=None)\n"
                 "--\n"
                 "\n"
                 "Return the list of stack frames for this task's coroutine.\n"
                 "\n"
                 "If the coroutine is not done, this returns the stack where it is\n"
                 "suspended.  If the coroutine has completed successfully or was\n"
                 "cancelled, this returns an empty list.  If the coroutine was\n"
                 "terminated by an exception, this returns the list of traceback\n"
                 "frames.\n"
                 "\n"
                 "The frames are always ordered from oldest to newest.\n"
                 "\n"
                 "The optional limit gives the maximum number of frames to\n"
                 "return; by default all available frames are returned.  Its\n"
                 "meaning differs depending on whether a stack or a traceback is\n"
                 "returned: the newest frames of a stack are returned, but the\n"
                 "oldest frames of a traceback are returned.  (This matches the\n"
                 "behavior of the traceback module.)\n"
                 "\n"
                 "For reasons beyond our control, only one stack frame is\n"
                 "returned for a suspended coroutine.",
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
                     Parameter(
                         name="limit",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="print_stack",
                 full_name="_asyncio.Task.print_stack",
                 c_basename="_asyncio_Task_print_stack",
                 cls="Task",
                 docstring="print_stack($self, /, *, limit=None, file=None)\n"
                 "--\n"
                 "\n"
                 "Print the stack or traceback for this task's coroutine.\n"
                 "\n"
                 "This produces output similar to that of the traceback module,\n"
                 "for the frames retrieved by get_stack().  The limit argument\n"
                 "is passed to get_stack().  The file argument is an I/O stream\n"
                 "to which the output is written; by default output is written\n"
                 "to sys.stderr.",
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
                     Parameter(
                         name="limit",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="file",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="set_result",
                 full_name="_asyncio.Task.set_result",
                 c_basename="_asyncio_Task_set_result",
                 cls="Task",
                 docstring="set_result($self, result, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="result", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="set_exception",
                 full_name="_asyncio.Task.set_exception",
                 c_basename="_asyncio_Task_set_exception",
                 cls="Task",
                 docstring="set_exception($self, exception, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="exception", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="get_coro",
                 full_name="_asyncio.Task.get_coro",
                 c_basename="_asyncio_Task_get_coro",
                 cls="Task",
                 docstring="get_coro($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="get_context",
                 full_name="_asyncio.Task.get_context",
                 c_basename="_asyncio_Task_get_context",
                 cls="Task",
                 docstring="get_context($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="get_name",
                 full_name="_asyncio.Task.get_name",
                 c_basename="_asyncio_Task_get_name",
                 cls="Task",
                 docstring="get_name($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="set_name",
                 full_name="_asyncio.Task.set_name",
                 c_basename="_asyncio_Task_set_name",
                 cls="Task",
                 docstring="set_name($self, value, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ],
         docs={
             "module_doc": "Accelerator module for asyncio",
             "FutureType_methods___class_getitem___doc": "Futures are generic over the type of their results",
             "TaskType_methods___class_getitem___doc": "Tasks are generic over the return type of their wrapped coroutines"
         }
     );
