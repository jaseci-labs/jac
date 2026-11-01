"""The Argument Clinic signatures of _pickle.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/pickle.jac from them. Taken from
the C sources it replaces (Modules/_pickle.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_pickle",
         version="3.14.6",
         sources=["Modules/_pickle.c"],
         classes={
             "Pickler": "PicklerObject *",
             "PicklerMemoProxy": "PicklerMemoProxyObject *",
             "Unpickler": "UnpicklerObject *",
             "UnpicklerMemoProxy": "UnpicklerMemoProxyObject *"
         },
         functions=[
             Function(
                 name="dump",
                 full_name="_pickle.dump",
                 c_basename="_pickle_dump",
                 docstring="dump($module, /, obj, file, protocol=None, *, fix_imports=True,\n"
                 "     buffer_callback=None)\n"
                 "--\n"
                 "\n"
                 "Write a pickled representation of obj to the open file object file.\n"
                 "\n"
                 "This is equivalent to ``Pickler(file, protocol).dump(obj)``, but may\n"
                 "be more efficient.\n"
                 "\n"
                 "The optional *protocol* argument tells the pickler to use the given\n"
                 "protocol; supported protocols are 0, 1, 2, 3, 4 and 5.  The default\n"
                 "protocol is 5. It was introduced in Python 3.8, and is incompatible\n"
                 "with previous versions.\n"
                 "\n"
                 "Specifying a negative protocol version selects the highest protocol\n"
                 "version supported.  The higher the protocol used, the more recent the\n"
                 "version of Python needed to read the pickle produced.\n"
                 "\n"
                 "The *file* argument must have a write() method that accepts a single\n"
                 "bytes argument.  It can thus be a file object opened for binary\n"
                 "writing, an io.BytesIO instance, or any other custom object that meets\n"
                 "this interface.\n"
                 "\n"
                 "If *fix_imports* is True and protocol is less than 3, pickle will try\n"
                 "to map the new Python 3 names to the old module names used in Python\n"
                 "2, so that the pickle data stream is readable with Python 2.\n"
                 "\n"
                 "If *buffer_callback* is None (the default), buffer views are serialized\n"
                 "into *file* as part of the pickle stream.  It is an error if\n"
                 "*buffer_callback* is not None and *protocol* is None or smaller than 5.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="obj", format_unit="O"),
                     Parameter(name="file", format_unit="O"),
                     Parameter(
                         name="protocol",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="fix_imports",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="buffer_callback",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3
             ),
             Function(
                 name="dumps",
                 full_name="_pickle.dumps",
                 c_basename="_pickle_dumps",
                 docstring="dumps($module, /, obj, protocol=None, *, fix_imports=True,\n"
                 "      buffer_callback=None)\n"
                 "--\n"
                 "\n"
                 "Return the pickled representation of the object as a bytes object.\n"
                 "\n"
                 "The optional *protocol* argument tells the pickler to use the given\n"
                 "protocol; supported protocols are 0, 1, 2, 3, 4 and 5.  The default\n"
                 "protocol is 5. It was introduced in Python 3.8, and is incompatible\n"
                 "with previous versions.\n"
                 "\n"
                 "Specifying a negative protocol version selects the highest protocol\n"
                 "version supported.  The higher the protocol used, the more recent the\n"
                 "version of Python needed to read the pickle produced.\n"
                 "\n"
                 "If *fix_imports* is True and *protocol* is less than 3, pickle will\n"
                 "try to map the new Python 3 names to the old module names used in\n"
                 "Python 2, so that the pickle data stream is readable with Python 2.\n"
                 "\n"
                 "If *buffer_callback* is None (the default), buffer views are serialized\n"
                 "into *file* as part of the pickle stream.  It is an error if\n"
                 "*buffer_callback* is not None and *protocol* is None or smaller than 5.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="obj", format_unit="O"),
                     Parameter(
                         name="protocol",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="fix_imports",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="buffer_callback",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="load",
                 full_name="_pickle.load",
                 c_basename="_pickle_load",
                 docstring="load($module, /, file, *, fix_imports=True, encoding='ASCII',\n"
                 "     errors='strict', buffers=())\n"
                 "--\n"
                 "\n"
                 "Read and return an object from the pickle data stored in a file.\n"
                 "\n"
                 "This is equivalent to ``Unpickler(file).load()``, but may be more\n"
                 "efficient.\n"
                 "\n"
                 "The protocol version of the pickle is detected automatically, so no\n"
                 "protocol argument is needed.  Bytes past the pickled object's\n"
                 "representation are ignored.\n"
                 "\n"
                 "The argument *file* must have two methods, a read() method that takes\n"
                 "an integer argument, and a readline() method that requires no\n"
                 "arguments.  Both methods should return bytes.  Thus *file* can be a\n"
                 "binary file object opened for reading, an io.BytesIO object, or any\n"
                 "other custom object that meets this interface.\n"
                 "\n"
                 "Optional keyword arguments are *fix_imports*, *encoding* and *errors*,\n"
                 "which are used to control compatibility support for pickle stream\n"
                 "generated by Python 2.  If *fix_imports* is True, pickle will try to\n"
                 "map the old Python 2 names to the new names used in Python 3.  The\n"
                 "*encoding* and *errors* tell pickle how to decode 8-bit string\n"
                 "instances pickled by Python 2; these default to 'ASCII' and 'strict',\n"
                 "respectively.  The *encoding* can be 'bytes' to read these 8-bit\n"
                 "string instances as bytes objects.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="file", format_unit="O"),
                     Parameter(
                         name="fix_imports",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="encoding",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="ASCII",
                         c_default="\"ASCII\""
                     ),
                     Parameter(
                         name="errors",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="strict",
                         c_default="\"strict\""
                     ),
                     Parameter(
                         name="buffers",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="loads",
                 full_name="_pickle.loads",
                 c_basename="_pickle_loads",
                 docstring="loads($module, data, /, *, fix_imports=True, encoding='ASCII',\n"
                 "      errors='strict', buffers=())\n"
                 "--\n"
                 "\n"
                 "Read and return an object from the given pickle data.\n"
                 "\n"
                 "The protocol version of the pickle is detected automatically, so no\n"
                 "protocol argument is needed.  Bytes past the pickled object's\n"
                 "representation are ignored.\n"
                 "\n"
                 "Optional keyword arguments are *fix_imports*, *encoding* and *errors*,\n"
                 "which are used to control compatibility support for pickle stream\n"
                 "generated by Python 2.  If *fix_imports* is True, pickle will try to\n"
                 "map the old Python 2 names to the new names used in Python 3.  The\n"
                 "*encoding* and *errors* tell pickle how to decode 8-bit string\n"
                 "instances pickled by Python 2; these default to 'ASCII' and 'strict',\n"
                 "respectively.  The *encoding* can be 'bytes' to read these 8-bit\n"
                 "string instances as bytes objects.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="data", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="fix_imports",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="encoding",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="ASCII",
                         c_default="\"ASCII\""
                     ),
                     Parameter(
                         name="errors",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="strict",
                         c_default="\"strict\""
                     ),
                     Parameter(
                         name="buffers",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="clear_memo",
                 full_name="_pickle.Pickler.clear_memo",
                 c_basename="_pickle_Pickler_clear_memo",
                 cls="Pickler",
                 docstring="clear_memo($self, /)\n"
                 "--\n"
                 "\n"
                 "Clears the pickler's \"memo\".\n"
                 "\n"
                 "The memo is the data structure that remembers which objects the\n"
                 "pickler has already seen, so that shared or recursive objects are\n"
                 "pickled by reference and not by value.  This method is useful when\n"
                 "re-using picklers.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="dump",
                 full_name="_pickle.Pickler.dump",
                 c_basename="_pickle_Pickler_dump",
                 cls="Pickler",
                 docstring="dump($self, obj, /)\n"
                 "--\n"
                 "\n"
                 "Write a pickled representation of the given object to the open file.",
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
                     Parameter(name="obj", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__sizeof__",
                 full_name="_pickle.Pickler.__sizeof__",
                 c_basename="_pickle_Pickler___sizeof__",
                 cls="Pickler",
                 docstring="__sizeof__($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns size in memory, in bytes.",
                 returns="size_t",
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
                 full_name="_pickle.Pickler.__init__",
                 c_basename="_pickle_Pickler___init__",
                 kind="METHOD_INIT",
                 cls="Pickler",
                 docstring="Pickler(file, protocol=None, fix_imports=True, buffer_callback=None)\n"
                 "--\n"
                 "\n"
                 "This takes a binary file for writing a pickle data stream.\n"
                 "\n"
                 "The optional *protocol* argument tells the pickler to use the given\n"
                 "protocol; supported protocols are 0, 1, 2, 3, 4 and 5.  The default\n"
                 "protocol is 5. It was introduced in Python 3.8, and is incompatible\n"
                 "with previous versions.\n"
                 "\n"
                 "Specifying a negative protocol version selects the highest protocol\n"
                 "version supported.  The higher the protocol used, the more recent the\n"
                 "version of Python needed to read the pickle produced.\n"
                 "\n"
                 "The *file* argument must have a write() method that accepts a single\n"
                 "bytes argument. It can thus be a file object opened for binary\n"
                 "writing, an io.BytesIO instance, or any other custom object that meets\n"
                 "this interface.\n"
                 "\n"
                 "If *fix_imports* is True and protocol is less than 3, pickle will try\n"
                 "to map the new Python 3 names to the old module names used in Python\n"
                 "2, so that the pickle data stream is readable with Python 2.\n"
                 "\n"
                 "If *buffer_callback* is None (the default), buffer views are\n"
                 "serialized into *file* as part of the pickle stream.\n"
                 "\n"
                 "If *buffer_callback* is not None, then it can be called any number\n"
                 "of times with a buffer view.  If the callback returns a false value\n"
                 "(such as None), the given buffer is out-of-band; otherwise the\n"
                 "buffer is serialized in-band, i.e. inside the pickle stream.\n"
                 "\n"
                 "It is an error if *buffer_callback* is not None and *protocol*\n"
                 "is None or smaller than 5.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="file", format_unit="O"),
                     Parameter(
                         name="protocol",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="fix_imports",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="buffer_callback",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=4
             ),
             Function(
                 name="clear",
                 full_name="_pickle.PicklerMemoProxy.clear",
                 c_basename="_pickle_PicklerMemoProxy_clear",
                 cls="PicklerMemoProxy",
                 docstring="clear($self, /)\n"
                 "--\n"
                 "\n"
                 "Remove all items from memo.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="copy",
                 full_name="_pickle.PicklerMemoProxy.copy",
                 c_basename="_pickle_PicklerMemoProxy_copy",
                 cls="PicklerMemoProxy",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Copy the memo to a new object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__reduce__",
                 full_name="_pickle.PicklerMemoProxy.__reduce__",
                 c_basename="_pickle_PicklerMemoProxy___reduce__",
                 cls="PicklerMemoProxy",
                 docstring="__reduce__($self, /)\n"
                 "--\n"
                 "\n"
                 "Implement pickle support.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="persistent_load",
                 full_name="_pickle.Unpickler.persistent_load",
                 c_basename="_pickle_Unpickler_persistent_load",
                 cls="Unpickler",
                 docstring="persistent_load($self, pid, /)\n" "--",
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
                     Parameter(name="pid", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="load",
                 full_name="_pickle.Unpickler.load",
                 c_basename="_pickle_Unpickler_load",
                 cls="Unpickler",
                 docstring="load($self, /)\n"
                 "--\n"
                 "\n"
                 "Load a pickle.\n"
                 "\n"
                 "Read a pickled object representation from the open file object given\n"
                 "in the constructor, and return the reconstituted object hierarchy\n"
                 "specified therein.",
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
                 name="find_class",
                 full_name="_pickle.Unpickler.find_class",
                 c_basename="_pickle_Unpickler_find_class",
                 cls="Unpickler",
                 docstring="find_class($self, module_name, global_name, /)\n"
                 "--\n"
                 "\n"
                 "Return an object from a specified module.\n"
                 "\n"
                 "If necessary, the module will be imported. Subclasses may override\n"
                 "this method (e.g. to restrict unpickling of arbitrary classes and\n"
                 "functions).\n"
                 "\n"
                 "This method is called whenever a class or a function object is\n"
                 "needed.  Both arguments passed are str objects.",
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
                         name="module_name", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="global_name", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="__sizeof__",
                 full_name="_pickle.Unpickler.__sizeof__",
                 c_basename="_pickle_Unpickler___sizeof__",
                 cls="Unpickler",
                 docstring="__sizeof__($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns size in memory, in bytes.",
                 returns="size_t",
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
                 full_name="_pickle.Unpickler.__init__",
                 c_basename="_pickle_Unpickler___init__",
                 kind="METHOD_INIT",
                 cls="Unpickler",
                 docstring="Unpickler(file, *, fix_imports=True, encoding='ASCII', errors='strict',\n"
                 "          buffers=())\n"
                 "--\n"
                 "\n"
                 "This takes a binary file for reading a pickle data stream.\n"
                 "\n"
                 "The protocol version of the pickle is detected automatically, so no\n"
                 "protocol argument is needed.  Bytes past the pickled object's\n"
                 "representation are ignored.\n"
                 "\n"
                 "The argument *file* must have two methods, a read() method that takes\n"
                 "an integer argument, and a readline() method that requires no\n"
                 "arguments.  Both methods should return bytes.  Thus *file* can be a\n"
                 "binary file object opened for reading, an io.BytesIO object, or any\n"
                 "other custom object that meets this interface.\n"
                 "\n"
                 "Optional keyword arguments are *fix_imports*, *encoding* and *errors*,\n"
                 "which are used to control compatibility support for pickle stream\n"
                 "generated by Python 2.  If *fix_imports* is True, pickle will try to\n"
                 "map the old Python 2 names to the new names used in Python 3.  The\n"
                 "*encoding* and *errors* tell pickle how to decode 8-bit string\n"
                 "instances pickled by Python 2; these default to 'ASCII' and 'strict',\n"
                 "respectively.  The *encoding* can be 'bytes' to read these 8-bit\n"
                 "string instances as bytes objects.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="file", format_unit="O"),
                     Parameter(
                         name="fix_imports",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="encoding",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="ASCII",
                         c_default="\"ASCII\""
                     ),
                     Parameter(
                         name="errors",
                         kind="KEYWORD_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="strict",
                         c_default="\"strict\""
                     ),
                     Parameter(
                         name="buffers",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="clear",
                 full_name="_pickle.UnpicklerMemoProxy.clear",
                 c_basename="_pickle_UnpicklerMemoProxy_clear",
                 cls="UnpicklerMemoProxy",
                 docstring="clear($self, /)\n"
                 "--\n"
                 "\n"
                 "Remove all items from memo.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="copy",
                 full_name="_pickle.UnpicklerMemoProxy.copy",
                 c_basename="_pickle_UnpicklerMemoProxy_copy",
                 cls="UnpicklerMemoProxy",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Copy the memo to a new object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__reduce__",
                 full_name="_pickle.UnpicklerMemoProxy.__reduce__",
                 c_basename="_pickle_UnpicklerMemoProxy___reduce__",
                 cls="UnpicklerMemoProxy",
                 docstring="__reduce__($self, /)\n"
                 "--\n"
                 "\n"
                 "Implement pickling support.",
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
             "pickle_module_doc": "Optimized C implementation for the Python pickle module.",
             "Pickler_methods_persistent_id_doc": "persistent_id($self, obj, /)\n"
             "--\n"
             "\n"
         }
     );
