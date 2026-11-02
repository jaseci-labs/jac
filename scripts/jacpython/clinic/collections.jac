"""The Argument Clinic signatures of _collections.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/collections.jac from them. Taken from
CPython 3.14.6 Modules/_collectionsmodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_collections",
         version="3.14.6",
         sources=["Modules/_collectionsmodule.c"],
         classes={"_tuplegetter": "_tuplegetterobject *", "deque": "dequeobject *"},
         functions=[
             Function(
                 name="__new__",
                 full_name="_tuplegetter.__new__",
                 c_basename="tuplegetter_new",
                 kind="METHOD_NEW",
                 cls="_tuplegetter",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="index",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(name="doc", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2,
                 self_type_check=True
             ),
             Function(
                 name="_count_elements",
                 full_name="_collections._count_elements",
                 c_basename="_collections__count_elements",
                 docstring="_count_elements($module, mapping, iterable, /)\n"
                 "--\n"
                 "\n"
                 "Count elements in the iterable, updating the mapping",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="mapping", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="pop",
                 full_name="_collections.deque.pop",
                 c_basename="deque_pop",
                 cls="deque",
                 docstring="pop($self, /)\n"
                 "--\n"
                 "\n"
                 "Remove and return the rightmost element.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="popleft",
                 full_name="_collections.deque.popleft",
                 c_basename="deque_popleft",
                 cls="deque",
                 docstring="popleft($self, /)\n"
                 "--\n"
                 "\n"
                 "Remove and return the leftmost element.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="append",
                 full_name="_collections.deque.append",
                 c_basename="deque_append",
                 cls="deque",
                 docstring="append($self, item, /)\n"
                 "--\n"
                 "\n"
                 "Add an element to the right side of the deque.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(name="item", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="appendleft",
                 full_name="_collections.deque.appendleft",
                 c_basename="deque_appendleft",
                 cls="deque",
                 docstring="appendleft($self, item, /)\n"
                 "--\n"
                 "\n"
                 "Add an element to the left side of the deque.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(name="item", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="extend",
                 full_name="_collections.deque.extend",
                 c_basename="deque_extend",
                 cls="deque",
                 docstring="extend($self, iterable, /)\n"
                 "--\n"
                 "\n"
                 "Extend the right side of the deque with elements from the iterable.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="extendleft",
                 full_name="_collections.deque.extendleft",
                 c_basename="deque_extendleft",
                 cls="deque",
                 docstring="extendleft($self, iterable, /)\n"
                 "--\n"
                 "\n"
                 "Extend the left side of the deque with elements from the iterable.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="copy",
                 full_name="_collections.deque.copy",
                 c_basename="deque_copy",
                 cls="deque",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a shallow copy of a deque.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__copy__",
                 full_name="_collections.deque.__copy__",
                 c_basename="deque___copy__",
                 cls="deque",
                 docstring="__copy__($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a shallow copy of a deque.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="clear",
                 full_name="_collections.deque.clear",
                 c_basename="deque_clearmethod",
                 cls="deque",
                 docstring="clear($self, /)\n"
                 "--\n"
                 "\n"
                 "Remove all elements from the deque.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="rotate",
                 full_name="_collections.deque.rotate",
                 c_basename="deque_rotate",
                 cls="deque",
                 docstring="rotate($self, n=1, /)\n"
                 "--\n"
                 "\n"
                 "Rotate the deque n steps to the right.  If n is negative, rotates left.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(
                         name="n",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
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
                 name="reverse",
                 full_name="_collections.deque.reverse",
                 c_basename="deque_reverse",
                 cls="deque",
                 docstring="reverse($self, /)\n" "--\n" "\n" "Reverse *IN PLACE*.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="count",
                 full_name="_collections.deque.count",
                 c_basename="deque_count",
                 cls="deque",
                 docstring="count($self, value, /)\n"
                 "--\n"
                 "\n"
                 "Return number of occurrences of value.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="index",
                 full_name="_collections.deque.index",
                 c_basename="deque_index",
                 cls="deque",
                 docstring="index($self, value, [start, [stop]])\n"
                 "--\n"
                 "\n"
                 "Return first index of value.\n"
                 "\n"
                 "Raises ValueError if the value is not present.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="start",
                         kind="POSITIONAL_ONLY",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="NULL",
                         c_default="0",
                         convert_with="_PyEval_SliceIndexNotNone"
                     ),
                     Parameter(
                         name="stop",
                         kind="POSITIONAL_ONLY",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="NULL",
                         c_default="PY_SSIZE_T_MAX",
                         convert_with="_PyEval_SliceIndexNotNone"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="insert",
                 full_name="_collections.deque.insert",
                 c_basename="deque_insert",
                 cls="deque",
                 docstring="insert($self, index, value, /)\n"
                 "--\n"
                 "\n"
                 "Insert value before index.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(
                         name="index",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="remove",
                 full_name="_collections.deque.remove",
                 c_basename="deque_remove",
                 cls="deque",
                 docstring="remove($self, value, /)\n"
                 "--\n"
                 "\n"
                 "Remove first occurrence of value.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__reduce__",
                 full_name="_collections.deque.__reduce__",
                 c_basename="deque___reduce__",
                 cls="deque",
                 docstring="__reduce__($self, /)\n"
                 "--\n"
                 "\n"
                 "Return state information for pickling.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__init__",
                 full_name="_collections.deque.__init__",
                 c_basename="deque_init",
                 kind="METHOD_INIT",
                 cls="deque",
                 docstring="deque([iterable[, maxlen]])\n"
                 "--\n"
                 "\n"
                 "A list-like sequence optimized for data accesses near its endpoints.",
                 returns="int",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     ),
                     Parameter(
                         name="iterable",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="maxlen",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="__sizeof__",
                 full_name="_collections.deque.__sizeof__",
                 c_basename="deque___sizeof__",
                 cls="deque",
                 docstring="__sizeof__($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the size of the deque in memory, in bytes.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__reversed__",
                 full_name="_collections.deque.__reversed__",
                 c_basename="deque___reversed__",
                 cls="deque",
                 docstring="__reversed__($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a reverse iterator over the deque.",
                 params=[
                     Parameter(
                         name="deque",
                         kind="POSITIONAL_ONLY",
                         converter="dequeobject",
                         type="dequeobject *"
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             )
         ],
         docs={
             "reduce_doc": "Return state information for pickling.",
             "length_hint_doc": "Private method returning an estimate of len(list(it)).",
             "defdict_missing_doc": "__missing__(key) # Called by __getitem__ for missing key; pseudo-code:\n"
             "  if self.default_factory is None: raise KeyError((key,))\n"
             "  self[key] = value = self.default_factory()\n"
             "  return value\n",
             "defdict_copy_doc": "D.copy() -> a shallow copy of D.",
             "defdict_class_getitem_doc": "defaultdicts are generic over two types, signifying (respectively) the types of the dictionary's keys and values",
             "defdict_doc": "defaultdict(default_factory=None, /, [...]) --> dict with default factory\n"
             "\n"
             "The default factory is called without arguments to produce\n"
             "a new value when a key is not present, in __getitem__ only.\n"
             "A defaultdict compares equal to a dict with the same items.\n"
             "All remaining arguments are treated the same as if they were\n"
             "passed to the dict constructor, including keyword arguments.\n",
             "collections_doc": "High performance data structures.\n"
             "- deque:        ordered collection accessible from endpoints only\n"
             "- defaultdict:  dict subclass with a default value factory\n",
             "deque_getset_maxlen_doc": "maximum size of a deque or None if unbounded",
             "deque_methods___class_getitem___doc": "deques are generic over the type of their contents",
             "defdict_members_default_factory_doc": "Factory for default value called by __missing__()."
         }
     );
