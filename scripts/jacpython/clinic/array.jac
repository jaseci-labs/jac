"""The Argument Clinic signatures of array.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/array.jac from them. Taken from
the C sources it replaces (Modules/arraymodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="array",
         version="3.14.6",
         sources=["Modules/arraymodule.c"],
         classes={"array": "arrayobject *", "arrayiterator": "arrayiterobject *"},
         functions=[
             Function(
                 name="_array_reconstructor",
                 full_name="array._array_reconstructor",
                 c_basename="array__array_reconstructor",
                 docstring="_array_reconstructor($module, arraytype, typecode, mformat_code, items,\n"
                 "                     /)\n"
                 "--\n"
                 "\n"
                 "Internal. Used for pickling support.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="arraytype",
                         kind="POSITIONAL_ONLY",
                         type="PyTypeObject *",
                         format_unit="O"
                     ),
                     Parameter(
                         name="typecode",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     ),
                     Parameter(
                         name="mformat_code",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="enum machine_format_code",
                         format_unit="i"
                     ),
                     Parameter(name="items", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=4,
                 max_pos=4,
                 pos_only=4
             ),
             Function(
                 name="clear",
                 full_name="array.array.clear",
                 c_basename="array_array_clear",
                 cls="array",
                 docstring="clear($self, /)\n"
                 "--\n"
                 "\n"
                 "Remove all items from the array.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__copy__",
                 full_name="array.array.__copy__",
                 c_basename="array_array___copy__",
                 cls="array",
                 docstring="__copy__($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy of the array.",
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
                 full_name="array.array.__deepcopy__",
                 c_basename="array_array___deepcopy__",
                 cls="array",
                 docstring="__deepcopy__($self, unused, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy of the array.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="unused", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="count",
                 full_name="array.array.count",
                 c_basename="array_array_count",
                 cls="array",
                 docstring="count($self, v, /)\n"
                 "--\n"
                 "\n"
                 "Return number of occurrences of v in the array.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="v", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="index",
                 full_name="array.array.index",
                 c_basename="array_array_index",
                 cls="array",
                 docstring="index($self, v, start=0, stop=sys.maxsize, /)\n"
                 "--\n"
                 "\n"
                 "Return index of first occurrence of v in the array.\n"
                 "\n"
                 "Raise ValueError if the value is not present.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="v", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="start",
                         kind="POSITIONAL_ONLY",
                         converter="slice_index",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         convert_with="_PyEval_SliceIndexNotNone"
                     ),
                     Parameter(
                         name="stop",
                         kind="POSITIONAL_ONLY",
                         converter="slice_index",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=9223372036854775807,
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
                 name="remove",
                 full_name="array.array.remove",
                 c_basename="array_array_remove",
                 cls="array",
                 docstring="remove($self, v, /)\n"
                 "--\n"
                 "\n"
                 "Remove the first occurrence of v in the array.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="v", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="pop",
                 full_name="array.array.pop",
                 c_basename="array_array_pop",
                 cls="array",
                 docstring="pop($self, i=-1, /)\n"
                 "--\n"
                 "\n"
                 "Return the i-th element and delete it from the array.\n"
                 "\n"
                 "i defaults to -1.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="i",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="extend",
                 full_name="array.array.extend",
                 c_basename="array_array_extend",
                 cls="array",
                 docstring="extend($self, bb, /)\n"
                 "--\n"
                 "\n"
                 "Append items to the end of the array.",
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
                     Parameter(name="bb", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="insert",
                 full_name="array.array.insert",
                 c_basename="array_array_insert",
                 cls="array",
                 docstring="insert($self, i, v, /)\n"
                 "--\n"
                 "\n"
                 "Insert a new item v into the array before position i.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="i",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(name="v", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="buffer_info",
                 full_name="array.array.buffer_info",
                 c_basename="array_array_buffer_info",
                 cls="array",
                 docstring="buffer_info($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a tuple (address, length) giving the current memory address and the length in items of the buffer used to hold array's contents.\n"
                 "\n"
                 "The length should be multiplied by the itemsize attribute to\n"
                 "calculate the buffer length in bytes.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="append",
                 full_name="array.array.append",
                 c_basename="array_array_append",
                 cls="array",
                 docstring="append($self, v, /)\n"
                 "--\n"
                 "\n"
                 "Append new value v to the end of the array.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="v", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="byteswap",
                 full_name="array.array.byteswap",
                 c_basename="array_array_byteswap",
                 cls="array",
                 docstring="byteswap($self, /)\n"
                 "--\n"
                 "\n"
                 "Byteswap all items of the array.\n"
                 "\n"
                 "If the items in the array are not 1, 2, 4, or 8 bytes in size,\n"
                 "RuntimeError is raised.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="reverse",
                 full_name="array.array.reverse",
                 c_basename="array_array_reverse",
                 cls="array",
                 docstring="reverse($self, /)\n"
                 "--\n"
                 "\n"
                 "Reverse the order of the items in the array.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fromfile",
                 full_name="array.array.fromfile",
                 c_basename="array_array_fromfile",
                 cls="array",
                 docstring="fromfile($self, f, n, /)\n"
                 "--\n"
                 "\n"
                 "Read n objects from the file object f and append them to the end of the array.",
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
                     Parameter(name="f", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="n",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="tofile",
                 full_name="array.array.tofile",
                 c_basename="array_array_tofile",
                 cls="array",
                 docstring="tofile($self, f, /)\n"
                 "--\n"
                 "\n"
                 "Write all items (as machine values) to the file object f.",
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
                     Parameter(name="f", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="fromlist",
                 full_name="array.array.fromlist",
                 c_basename="array_array_fromlist",
                 cls="array",
                 docstring="fromlist($self, list, /)\n"
                 "--\n"
                 "\n"
                 "Append items to array from list.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="list", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="tolist",
                 full_name="array.array.tolist",
                 c_basename="array_array_tolist",
                 cls="array",
                 docstring="tolist($self, /)\n"
                 "--\n"
                 "\n"
                 "Convert array to an ordinary list with the same items.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="frombytes",
                 full_name="array.array.frombytes",
                 c_basename="array_array_frombytes",
                 cls="array",
                 docstring="frombytes($self, buffer, /)\n"
                 "--\n"
                 "\n"
                 "Appends items from the string, interpreting it as an array of machine values, as if it had been read from a file using the fromfile() method.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="buffer",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="tobytes",
                 full_name="array.array.tobytes",
                 c_basename="array_array_tobytes",
                 cls="array",
                 docstring="tobytes($self, /)\n"
                 "--\n"
                 "\n"
                 "Convert the array to an array of machine values and return the bytes representation.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fromunicode",
                 full_name="array.array.fromunicode",
                 c_basename="array_array_fromunicode",
                 cls="array",
                 docstring="fromunicode($self, ustr, /)\n"
                 "--\n"
                 "\n"
                 "Extends this array with data from the unicode string ustr.\n"
                 "\n"
                 "The array must be a unicode type array; otherwise a ValueError is\n"
                 "raised.  Use array.frombytes(ustr.encode(...)) to append Unicode\n"
                 "data to an array of some other type.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="ustr",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="tounicode",
                 full_name="array.array.tounicode",
                 c_basename="array_array_tounicode",
                 cls="array",
                 docstring="tounicode($self, /)\n"
                 "--\n"
                 "\n"
                 "Extends this array with data from the unicode string ustr.\n"
                 "\n"
                 "Convert the array to a unicode string.  The array must be a unicode\n"
                 "type array; otherwise a ValueError is raised.  Use\n"
                 "array.tobytes().decode() to obtain a unicode string from an array of\n"
                 "some other type.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__sizeof__",
                 full_name="array.array.__sizeof__",
                 c_basename="array_array___sizeof__",
                 cls="array",
                 docstring="__sizeof__($self, /)\n"
                 "--\n"
                 "\n"
                 "Size of the array in memory, in bytes.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__reduce_ex__",
                 full_name="array.array.__reduce_ex__",
                 c_basename="array_array___reduce_ex__",
                 cls="array",
                 docstring="__reduce_ex__($self, value, /)\n"
                 "--\n"
                 "\n"
                 "Return state information for pickling.",
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
                     Parameter(name="value", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__reduce__",
                 full_name="array.arrayiterator.__reduce__",
                 c_basename="array_arrayiterator___reduce__",
                 cls="arrayiterator",
                 docstring="__reduce__($self, /)\n"
                 "--\n"
                 "\n"
                 "Return state information for pickling.",
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
                 name="__setstate__",
                 full_name="array.arrayiterator.__setstate__",
                 c_basename="array_arrayiterator___setstate__",
                 cls="arrayiterator",
                 docstring="__setstate__($self, state, /)\n"
                 "--\n"
                 "\n"
                 "Set state information for unpickling.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="state", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ],
         docs={
             "module_doc": "This module defines an object type which can efficiently represent\n"
             "an array of basic values: characters, integers, floating-point\n"
             "numbers.  Arrays are sequence types and behave very much like lists,\n"
             "except that the type of objects stored in them is constrained.\n",
             "arraytype_doc": "array(typecode [, initializer]) -> array\n"
             "\n"
             "Return a new array whose items are restricted by typecode, and\n"
             "initialized from the optional initializer value, which must be a list,\n"
             "string or iterable over elements of the appropriate type.\n"
             "\n"
             "Arrays represent basic values and behave very much like lists, except\n"
             "the type of objects stored in them is constrained. The type is specified\n"
             "at object creation time by using a type code, which is a single character.\n"
             "The following type codes are defined:\n"
             "\n"
             "    Type code   C Type             Minimum size in bytes\n"
             "    'b'         signed integer     1\n"
             "    'B'         unsigned integer   1\n"
             "    'u'         Unicode character  2 (see note)\n"
             "    'h'         signed integer     2\n"
             "    'H'         unsigned integer   2\n"
             "    'i'         signed integer     2\n"
             "    'I'         unsigned integer   2\n"
             "    'l'         signed integer     4\n"
             "    'L'         unsigned integer   4\n"
             "    'q'         signed integer     8 (see note)\n"
             "    'Q'         unsigned integer   8 (see note)\n"
             "    'f'         floating-point     4\n"
             "    'd'         floating-point     8\n"
             "\n"
             "NOTE: The 'u' typecode corresponds to Python's unicode character. On\n"
             "narrow builds this is 2-bytes on wide builds this is 4-bytes.\n"
             "\n"
             "NOTE: The 'q' and 'Q' type codes are only available if the platform\n"
             "C compiler used to build Python supports 'long long', or, on Windows,\n"
             "'__int64'.\n"
             "\n"
             "Methods:\n"
             "\n"
             "append() -- append a new item to the end of the array\n"
             "buffer_info() -- return information giving the current memory info\n"
             "byteswap() -- byteswap all the items of the array\n"
             "count() -- return number of occurrences of an object\n"
             "extend() -- extend array by appending multiple elements from an iterable\n"
             "fromfile() -- read items from a file object\n"
             "fromlist() -- append items from the list\n"
             "frombytes() -- append items from the string\n"
             "index() -- return index of first occurrence of an object\n"
             "insert() -- insert a new item into the array at a provided position\n"
             "pop() -- remove and return item (default last)\n"
             "remove() -- remove first occurrence of an object\n"
             "reverse() -- reverse the order of the items in the array\n"
             "tofile() -- write all items to a file object\n"
             "tolist() -- return the array converted to an ordinary list\n"
             "tobytes() -- return the array converted to a string\n"
             "\n"
             "Attributes:\n"
             "\n"
             "typecode -- the typecode character used to create the array\n"
             "itemsize -- the length in bytes of one array item\n",
             "array_getsets_typecode_doc": "the typecode character used to create the array",
             "array_getsets_itemsize_doc": "the size, in bytes, of one array item",
             "array_methods___class_getitem___doc": "Arrays are generic over the type of their elements"
         }
     );
