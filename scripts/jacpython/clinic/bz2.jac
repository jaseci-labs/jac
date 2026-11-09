"""The Argument Clinic signatures of _bz2.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/bz2.jac from them. Taken from
CPython 3.14.6 Modules/_bz2module.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_bz2",
         version="3.14.6",
         sources=["Modules/_bz2module.c"],
         classes={
             "BZ2Compressor": "BZ2Compressor *",
             "BZ2Decompressor": "BZ2Decompressor *"
         },
         functions=[
             Function(
                 name="compress",
                 full_name="_bz2.BZ2Compressor.compress",
                 c_basename="_bz2_BZ2Compressor_compress",
                 cls="BZ2Compressor",
                 docstring="compress($self, data, /)\n"
                 "--\n"
                 "\n"
                 "Provide data to the compressor object.\n"
                 "\n"
                 "Returns a chunk of compressed data if possible, or b'' otherwise.\n"
                 "\n"
                 "When you have finished providing data to the compressor, call the\n"
                 "flush() method to finish the compression process.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="data",
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
                 name="flush",
                 full_name="_bz2.BZ2Compressor.flush",
                 c_basename="_bz2_BZ2Compressor_flush",
                 cls="BZ2Compressor",
                 docstring="flush($self, /)\n"
                 "--\n"
                 "\n"
                 "Finish the compression process.\n"
                 "\n"
                 "Returns the compressed data left in internal buffers.\n"
                 "\n"
                 "The compressor object may not be used after this method is called.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__new__",
                 full_name="_bz2.BZ2Compressor.__new__",
                 c_basename="_bz2_BZ2Compressor",
                 kind="METHOD_NEW",
                 cls="BZ2Compressor",
                 docstring="BZ2Compressor(compresslevel=9, /)\n"
                 "--\n"
                 "\n"
                 "Create a compressor object for compressing data incrementally.\n"
                 "\n"
                 "  compresslevel\n"
                 "    Compression level, as a number between 1 and 9.\n"
                 "\n"
                 "For one-shot compression, use the compress() function instead.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="compresslevel",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=9,
                         c_default="9"
                     )
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1,
                 self_type_check=True
             ),
             Function(
                 name="decompress",
                 full_name="_bz2.BZ2Decompressor.decompress",
                 c_basename="_bz2_BZ2Decompressor_decompress",
                 cls="BZ2Decompressor",
                 docstring="decompress($self, /, data, max_length=-1)\n"
                 "--\n"
                 "\n"
                 "Decompress *data*, returning uncompressed data as bytes.\n"
                 "\n"
                 "If *max_length* is nonnegative, returns at most *max_length* bytes\n"
                 "of decompressed data.  If this limit is reached and further output\n"
                 "can be produced, *self.needs_input* will be set to ``False``.  In\n"
                 "this case, the next call to *decompress()* may provide *data* as b''\n"
                 "to obtain more of the output.\n"
                 "\n"
                 "If all of the input data was decompressed and returned (either\n"
                 "because this was less than *max_length* bytes, or because\n"
                 "*max_length* was negative), *self.needs_input* will be set to True.\n"
                 "\n"
                 "Attempting to decompress data after the end of stream is reached\n"
                 "raises an EOFError.  Any data found after the end of the stream is\n"
                 "ignored and saved in the unused_data attribute.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="data",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="max_length",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="_bz2.BZ2Decompressor.__new__",
                 c_basename="_bz2_BZ2Decompressor",
                 kind="METHOD_NEW",
                 cls="BZ2Decompressor",
                 docstring="BZ2Decompressor()\n"
                 "--\n"
                 "\n"
                 "Create a decompressor object for decompressing data incrementally.\n"
                 "\n"
                 "For one-shot decompression, use the decompress() function instead.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_NOTHING",
                 self_type_check=True
             )
         ],
         docs={
             "BZ2Decompressor_eof__doc__": "True if the end-of-stream marker has been reached.",
             "BZ2Decompressor_unused_data__doc__": "Data found after the end of the compressed stream.",
             "BZ2Decompressor_needs_input_doc": "True if more input is needed before more decompressed data can be produced."
         }
     );
