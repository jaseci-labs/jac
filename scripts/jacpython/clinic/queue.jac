"""The Argument Clinic signatures of _queue.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/queue.jac from them. Taken from
CPython 3.14.6 Modules/_queuemodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_queue",
         version="3.14.6",
         sources=["Modules/_queuemodule.c"],
         classes={"SimpleQueue": "simplequeueobject *"},
         functions=[
             Function(
                 name="__new__",
                 full_name="_queue.SimpleQueue.__new__",
                 c_basename="simplequeue_new",
                 kind="METHOD_NEW",
                 cls="SimpleQueue",
                 docstring="SimpleQueue()\n"
                 "--\n"
                 "\n"
                 "Simple, unbounded, reentrant FIFO queue.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_NOTHING",
                 self_type_check=True
             ),
             Function(
                 name="put",
                 full_name="_queue.SimpleQueue.put",
                 c_basename="_queue_SimpleQueue_put",
                 cls="SimpleQueue",
                 docstring="put($self, /, item, block=True, timeout=None)\n"
                 "--\n"
                 "\n"
                 "Put the item on the queue.\n"
                 "\n"
                 "The optional 'block' and 'timeout' arguments are ignored, as this\n"
                 "method never blocks.  They are provided for compatibility with the\n"
                 "Queue class.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="item", format_unit="O"),
                     Parameter(
                         name="block",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="timeout",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="put_nowait",
                 full_name="_queue.SimpleQueue.put_nowait",
                 c_basename="_queue_SimpleQueue_put_nowait",
                 cls="SimpleQueue",
                 docstring="put_nowait($self, /, item)\n"
                 "--\n"
                 "\n"
                 "Put an item into the queue without blocking.\n"
                 "\n"
                 "This is exactly equivalent to `put(item)` and is only provided\n"
                 "for compatibility with the Queue class.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="item", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="get",
                 full_name="_queue.SimpleQueue.get",
                 c_basename="_queue_SimpleQueue_get",
                 cls="SimpleQueue",
                 docstring="get($self, /, block=True, timeout=None)\n"
                 "--\n"
                 "\n"
                 "Remove and return an item from the queue.\n"
                 "\n"
                 "If optional args 'block' is true and 'timeout' is None (the\n"
                 "default), block if necessary until an item is available.  If\n"
                 "'timeout' is a non-negative number, it blocks at most 'timeout'\n"
                 "seconds and raises the Empty exception if no item was available\n"
                 "within that time.\n"
                 "Otherwise ('block' is false), return an item if one is immediately\n"
                 "available, else raise the Empty exception ('timeout' is ignored\n"
                 "in that case).",
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
                         name="block",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="timeout",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="get_nowait",
                 full_name="_queue.SimpleQueue.get_nowait",
                 c_basename="_queue_SimpleQueue_get_nowait",
                 cls="SimpleQueue",
                 docstring="get_nowait($self, /)\n"
                 "--\n"
                 "\n"
                 "Remove and return an item from the queue without blocking.\n"
                 "\n"
                 "Only get an item if one is immediately available. Otherwise\n"
                 "raise the Empty exception.",
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
                 name="empty",
                 full_name="_queue.SimpleQueue.empty",
                 c_basename="_queue_SimpleQueue_empty",
                 cls="SimpleQueue",
                 docstring="empty($self, /)\n"
                 "--\n"
                 "\n"
                 "Return True if the queue is empty, False otherwise (not reliable!).",
                 returns="bool",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="qsize",
                 full_name="_queue.SimpleQueue.qsize",
                 c_basename="_queue_SimpleQueue_qsize",
                 cls="SimpleQueue",
                 docstring="qsize($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the approximate size of the queue (not reliable!).",
                 returns="Py_ssize_t",
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
             "queue_module_doc": "C implementation of the Python queue module.\n"
             "This module is an implementation detail, please do not use it directly.",
             "simplequeue_methods___class_getitem___doc": "SimpleQueues are generic over the type of their contents"
         }
     );
