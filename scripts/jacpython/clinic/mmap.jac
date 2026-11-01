"""The Argument Clinic signatures of mmap.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/mmap.jac from them. Taken from
the C sources it replaces (Modules/mmapmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="mmap",
         version="3.14.6",
         sources=["Modules/mmapmodule.c"],
         classes={"mmap": "mmap_object *"},
         functions=[
             Function(
                 name="close",
                 full_name="mmap.mmap.close",
                 c_basename="mmap_mmap_close",
                 cls="mmap",
                 docstring="close($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="read_byte",
                 full_name="mmap.mmap.read_byte",
                 c_basename="mmap_mmap_read_byte",
                 cls="mmap",
                 docstring="read_byte($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="readline",
                 full_name="mmap.mmap.readline",
                 c_basename="mmap_mmap_readline",
                 cls="mmap",
                 docstring="readline($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="read",
                 full_name="mmap.mmap.read",
                 c_basename="mmap_mmap_read",
                 cls="mmap",
                 docstring="read($self, n=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="n",
                         kind="POSITIONAL_ONLY",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="PY_SSIZE_T_MAX",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="find",
                 full_name="mmap.mmap.find",
                 c_basename="mmap_mmap_find",
                 cls="mmap",
                 docstring="find($self, view, start=None, end=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="view",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="start",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="end",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="rfind",
                 full_name="mmap.mmap.rfind",
                 c_basename="mmap_mmap_rfind",
                 cls="mmap",
                 docstring="rfind($self, view, start=None, end=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="view",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="start",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="end",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="write",
                 full_name="mmap.mmap.write",
                 c_basename="mmap_mmap_write",
                 cls="mmap",
                 docstring="write($self, bytes, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="bytes",
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
                 name="write_byte",
                 full_name="mmap.mmap.write_byte",
                 c_basename="mmap_mmap_write_byte",
                 cls="mmap",
                 docstring="write_byte($self, byte, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="byte",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_char",
                         type="unsigned char",
                         format_unit="b"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="size",
                 full_name="mmap.mmap.size",
                 c_basename="mmap_mmap_size",
                 cls="mmap",
                 docstring="size($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="resize",
                 full_name="mmap.mmap.resize",
                 c_basename="mmap_mmap_resize",
                 cls="mmap",
                 docstring="resize($self, newsize, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="newsize",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="tell",
                 full_name="mmap.mmap.tell",
                 c_basename="mmap_mmap_tell",
                 cls="mmap",
                 docstring="tell($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="flush",
                 full_name="mmap.mmap.flush",
                 c_basename="mmap_mmap_flush",
                 cls="mmap",
                 docstring="flush($self, offset=0, size=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="seek",
                 full_name="mmap.mmap.seek",
                 c_basename="mmap_mmap_seek",
                 cls="mmap",
                 docstring="seek($self, pos, whence=0, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="pos",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="whence",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="seekable",
                 full_name="mmap.mmap.seekable",
                 c_basename="mmap_mmap_seekable",
                 cls="mmap",
                 docstring="seekable($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="move",
                 full_name="mmap.mmap.move",
                 c_basename="mmap_mmap_move",
                 cls="mmap",
                 docstring="move($self, dest, src, count, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="dest",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="src",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="count",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="__enter__",
                 full_name="mmap.mmap.__enter__",
                 c_basename="mmap_mmap___enter__",
                 cls="mmap",
                 docstring="__enter__($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__exit__",
                 full_name="mmap.mmap.__exit__",
                 c_basename="mmap_mmap___exit__",
                 cls="mmap",
                 docstring="__exit__($self, exc_type, exc_value, traceback, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="exc_type", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="exc_value", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="traceback", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="__sizeof__",
                 full_name="mmap.mmap.__sizeof__",
                 c_basename="mmap_mmap___sizeof__",
                 cls="mmap",
                 docstring="__sizeof__($self, /)\n" "--",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_protect",
                 full_name="mmap.mmap._protect",
                 c_basename="mmap_mmap__protect",
                 cls="mmap",
                 docstring="_protect($self, flNewProtect, start, length, /)\n" "--",
                 condition="(defined(MS_WINDOWS) && defined(Py_DEBUG))",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="flNewProtect",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="I"
                     ),
                     Parameter(
                         name="start",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="length",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="madvise",
                 full_name="mmap.mmap.madvise",
                 c_basename="mmap_mmap_madvise",
                 cls="mmap",
                 docstring="madvise($self, option, start=0, length=None, /)\n" "--",
                 condition="defined(HAVE_MADVISE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="option",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="start",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="length",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=3,
                 pos_only=3
             )
         ],
         docs={
             "mmap_doc": "Windows: mmap(fileno, length[, tagname[, access[, offset]]])\n"
             "\n"
             "Maps length bytes from the file specified by the file handle fileno,\n"
             "and returns a mmap object.  If length is larger than the current size\n"
             "of the file, the file is extended to contain length bytes.  If length\n"
             "is 0, the maximum length of the map is the current size of the file,\n"
             "except that if the file is empty Windows raises an exception (you cannot\n"
             "create an empty mapping on Windows).\n"
             "\n"
             "Unix: mmap(fileno, length[, flags[, prot[, access[, offset[, trackfd]]]]])\n"
             "\n"
             "Maps length bytes from the file specified by the file descriptor fileno,\n"
             "and returns a mmap object.  If length is 0, the maximum length of the map\n"
             "will be the current size of the file when mmap is called.\n"
             "flags specifies the nature of the mapping. MAP_PRIVATE creates a\n"
             "private copy-on-write mapping, so changes to the contents of the mmap\n"
             "object will be private to this process, and MAP_SHARED creates a mapping\n"
             "that's shared with all other processes mapping the same areas of the file.\n"
             "The default value is MAP_SHARED.\n"
             "\n"
             "To map anonymous memory, pass -1 as the fileno (both versions)."
         }
     );
